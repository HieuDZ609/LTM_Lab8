# ============================================================================
#  CÀI ĐẶT / CẤU HÌNH MySQL CHO SERVER 1 HOẶC SERVER 2 TRÊN WINDOWS
#
#  Yêu cầu: đã cài MySQL Server 8.0/8.4 bằng MySQL Installer.
#  Chạy PowerShell với quyền Administrator:
#
#     cd <thư mục dự án>
#     Set-ExecutionPolicy -Scope Process Bypass -Force
#     .\scripts\setup_mysql_windows.ps1 -ServerId 2 -RootPass "mat_khau_root"
#
#  Script sẽ:
#    1. Sao lưu my.ini
#    2. Bật bind-address=0.0.0.0, server-id, GTID, binlog, log_replica_updates
#    3. Khởi động lại service MySQL
#    4. Tạo database shared_records + bảng + user appuser/replicator
#    5. Mở firewall cổng 3306
# ============================================================================
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet(1, 2)]
    [int]$ServerId,

    [string]$RootPass = "",

    [string]$MyIniPath = "",

    [switch]$SkipFirewall
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'mysql_common.ps1')

function Write-Step($text) { Write-Host "`n==> $text" -ForegroundColor Cyan }
function Write-Ok($text)   { Write-Host "    OK  $text" -ForegroundColor Green }
function Write-Warn2($text){ Write-Host "    !   $text" -ForegroundColor Yellow }
function Write-Err($text)  { Write-Host "    X   $text" -ForegroundColor Red }

Write-Host "==============================================================" -ForegroundColor White
Write-Host "  CẤU HÌNH MySQL CHO SERVER $ServerId (Windows)" -ForegroundColor White
Write-Host "==============================================================" -ForegroundColor White

if (-not (Test-Admin)) {
    Write-Err "Hãy mở PowerShell bằng 'Run as administrator' rồi chạy lại."
    exit 1
}

# ---------------------------------------------------------------- 1. service
Write-Step "Tìm service MySQL"
$svc = Get-MysqlService
if (-not $svc) {
    Write-Err "Không thấy service MySQL. Hãy cài MySQL Server 8.4 bằng MySQL Installer trước."
    exit 1
}
Write-Ok "Service: $($svc.Name)  ($($svc.State))"

# ---------------------------------------------------------------- 2. mysql.exe
Write-Step "Tìm mysql.exe"
$mysqlExe = Get-MysqlExe -ServiceName $svc.Name
if (-not $mysqlExe) {
    Write-Err "Không tìm thấy mysql.exe. Kiểm tra lại thư mục cài MySQL."
    exit 1
}
Write-Ok $mysqlExe

# ---------------------------------------------------------------- 3. my.ini
Write-Step "Tìm file cấu hình my.ini"
if (-not $MyIniPath) { $MyIniPath = Get-MyIniPath -Service $svc }
if (-not $MyIniPath -or -not (Test-Path $MyIniPath)) {
    Write-Err "Không tìm thấy my.ini. Truyền đường dẫn thủ công: -MyIniPath 'C:\ProgramData\MySQL\MySQL Server 8.4\my.ini'"
    exit 1
}
Write-Ok $MyIniPath

$backup = "$MyIniPath.bak_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
Copy-Item -LiteralPath $MyIniPath -Destination $backup -Force
Write-Ok "Đã sao lưu: $backup"

# ---------------------------------------------------------------- 4. sửa my.ini
Write-Step "Bật GTID + binlog + log_replica_updates + bind-address"

$settings = [ordered]@{
    'server-id'                = "$ServerId"
    'log-bin'                  = 'mysql-bin'
    'binlog_format'            = 'ROW'
    'gtid_mode'                = 'ON'
    'enforce_gtid_consistency' = 'ON'
    'log_replica_updates'      = 'ON'
    'binlog_expire_logs_seconds' = '604800'
    'bind-address'             = '0.0.0.0'
    'max_connections'          = '200'
}

foreach ($k in $settings.Keys) {
    Set-IniKey -Path $MyIniPath -Section 'mysqld' -Key $k -Value $settings[$k]
    Write-Ok "$k = $($settings[$k])"
}

# ---------------------------------------------------------------- 5. restart
Write-Step "Khởi động lại service MySQL"
try {
    if ($svc.State -eq 'Running') {
        Restart-Service -Name $svc.Name -Force
    } else {
        Start-Service -Name $svc.Name
    }
} catch {
    Write-Err "Không khởi động lại được service: $($_.Exception.Message)"
    Write-Host "    Khôi phục my.ini từ: $backup"
    Write-Host "    Rồi chạy: Restart-Service $($svc.Name)"
    exit 1
}
if (-not (Wait-MysqlPort -Port 3306 -TimeoutSec 60)) {
    Write-Err "MySQL không mở cổng 3306 sau khi restart. Xem log: $MyIniPath (mục log-error) hoặc C:\ProgramData\MySQL\*.err"
    exit 1
}
Write-Ok "MySQL đã chạy lại"

# ---------------------------------------------------------------- 6. database
Write-Step "Tạo database shared_records + bảng + user"
$sqlFile = Join-Path (Split-Path $PSScriptRoot -Parent) 'sql\init_shared_records.sql'
if (-not (Test-Path $sqlFile)) {
    Write-Err "Không thấy $sqlFile"
    exit 1
}
$sqlFileMysql = $sqlFile -replace '\\', '/'
$rc = Invoke-MysqlRoot -MysqlExe $mysqlExe -RootPass $RootPass -ArgList @('-e', "source $sqlFileMysql")
if ($rc -ne 0) {
    Write-Err "Chạy SQL thất bại (exit=$rc). Nếu root có mật khẩu, thêm: -RootPass 'mat_khau'"
    exit 1
}
Write-Ok "Đã tạo DB/bảng/user"

# ---------------------------------------------------------------- 7. firewall
if (-not $SkipFirewall) {
    Write-Step "Mở firewall TCP 3306"
    $ruleName = 'MySQL Server 3306'
    if (Get-NetFirewallRule -DisplayName $ruleName -ErrorAction SilentlyContinue) {
        Write-Ok "Rule đã tồn tại"
    } else {
        New-NetFirewallRule -DisplayName $ruleName -Direction Inbound -Protocol TCP `
            -LocalPort 3306 -Action Allow -Profile Any | Out-Null
        Write-Ok "Đã thêm rule '$ruleName'"
    }
}

# ---------------------------------------------------------------- 8. kiểm tra
Write-Step "Kiểm tra cấu hình"
Invoke-MysqlRoot -MysqlExe $mysqlExe -RootPass $RootPass -ArgList @(
    '-e', "SELECT @@server_id AS server_id, @@gtid_mode AS gtid_mode, @@log_replica_updates AS log_replica_updates; SHOW DATABASES LIKE 'shared_records';"
) | Out-Null

Write-Host ""
Write-Host "==============================================================" -ForegroundColor Green
Write-Host " XONG. Server $ServerId đã sẵn sàng." -ForegroundColor Green
Write-Host "==============================================================" -ForegroundColor Green
Write-Host ""
Write-Host "BƯỚC TIẾP THEO — bật đồng bộ hai chiều:" -ForegroundColor White
Write-Host "  Server 1 (máy bạn)   : .\scripts\setup_replication_windows.ps1 -PeerHost 192.168.161.131 -RootPass '...'"
Write-Host "  Server 2 (máy bạn bè): .\scripts\setup_replication_windows.ps1 -PeerHost 172.16.228.141 -RootPass '...'"
Write-Host ""
Write-Host "Kiểm tra nhanh:" -ForegroundColor White
Write-Host "  & '$mysqlExe' -u root -p -e \"SHOW REPLICA STATUS\G\""
Write-Host ""
