# ============================================================================
#  BẬT ĐỒNG BỘ HAI CHIỀU (GTID) TRÊN WINDOWS
#
#  Chạy PowerShell với quyền Administrator, TRÊN TỪNG SERVER:
#
#     cd <thư mục dự án>
#     Set-ExecutionPolicy -Scope Process Bypass -Force
#     .\scripts\setup_replication_windows.ps1 -PeerHost <IP_SERVER_KIA> -RootPass "mat_khau_root"
#
#  Ví dụ:
#     Server 1: .\scripts\setup_replication_windows.ps1 -PeerHost 192.168.161.131
#     Server 2: .\scripts\setup_replication_windows.ps1 -PeerHost 172.16.228.141
# ============================================================================
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$PeerHost,

    [int]$PeerPort = 3306,

    [string]$RootPass = "",

    [string]$ReplUser = 'replicator',

    [string]$ReplPass = 'replica123',

    [switch]$NoSsl
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'mysql_common.ps1')

function Write-Step($text) { Write-Host "`n==> $text" -ForegroundColor Cyan }
function Write-Ok($text)   { Write-Host "    OK  $text" -ForegroundColor Green }
function Write-Err($text)  { Write-Host "    X   $text" -ForegroundColor Red }

Write-Host "==============================================================" -ForegroundColor White
Write-Host "  ĐỒNG BỘ HAI CHIỀU -> $PeerHost`:$PeerPort" -ForegroundColor White
Write-Host "==============================================================" -ForegroundColor White

if (-not (Test-Admin)) {
    Write-Err "Hãy mở PowerShell bằng 'Run as administrator' rồi chạy lại."
    exit 1
}

$mysqlExe = Get-MysqlExe
if (-not $mysqlExe) { Write-Err "Không tìm thấy mysql.exe"; exit 1 }

Write-Step "Kiểm tra kết nối tới $PeerHost`:$PeerPort"
if (-not (Test-TcpPort -ComputerName $PeerHost -Port $PeerPort -TimeoutMs 5000)) {
    Write-Err "KHÔNG kết nối được tới $PeerHost`:$PeerPort"
    Write-Host "    - MySQL máy kia đã chạy chưa?"
    Write-Host "    - Firewall máy kia có mở 3306?"
    Write-Host "    - VMware đang NAT hay Bridged? (xem docs/05_HUONG_DAN_WINDOWS.md)"
    exit 1
}
Write-Ok "Kết nối TCP thành công"

$sslOption = if ($NoSsl) { "SOURCE_SSL=0," } else { "SOURCE_SSL=1," }

$sql = @"
STOP REPLICA;
RESET REPLICA ALL;
CHANGE REPLICATION SOURCE TO
  SOURCE_HOST='$PeerHost',
  SOURCE_PORT=$PeerPort,
  SOURCE_USER='$ReplUser',
  SOURCE_PASSWORD='$ReplPass',
  SOURCE_AUTO_POSITION=1,
  $sslOption
  SOURCE_CONNECT_RETRY=10,
  SOURCE_RETRY_COUNT=86400;
START REPLICA;
"@

Write-Step "Cấu hình replica (GTID auto-position)"
$rc = Invoke-MysqlRoot -MysqlExe $mysqlExe -RootPass $RootPass -ArgList @('-e', $sql)
if ($rc -ne 0) {
    Write-Err "Cấu hình thất bại. Nếu root có mật khẩu: thêm -RootPass 'mat_khau'"
    exit 1
}

Start-Sleep -Seconds 4

Write-Step "Trạng thái đồng bộ"
$statusArgs = @('-u', 'root')
if ($RootPass -ne '') { $statusArgs += "-p$RootPass" }
$statusArgs += @('-e', 'SHOW REPLICA STATUS\G')
$status = & $mysqlExe @statusArgs 2>&1
$lines = $status | Select-String -Pattern 'Replica_IO_Running|Replica_SQL_Running|Seconds_Behind_Source|Last_IO_Error|Last_SQL_Error|Source_Host'
if (-not $lines) {
    Write-Err "Không đọc được trạng thái (sai mật khẩu root?)"
} else {
    $lines | ForEach-Object { Write-Host "    $_" }
}

Write-Host ""
Write-Host "Replica_IO_Running = Yes  và  Replica_SQL_Running = Yes  =>  đồng bộ đã chạy." -ForegroundColor Green
Write-Host "Nếu = Connecting: kiểm tra IP, user 'replicator', mật khẩu, firewall 3306." -ForegroundColor Yellow
Write-Host ""
