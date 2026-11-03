# ============================================================
#  Hàm dùng chung cho các script Windows (.ps1)
#  Được "dot-source" bởi setup_mysql_windows.ps1 / setup_replication_windows.ps1
# ============================================================

function Test-Admin {
    $p = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    return $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Get-MysqlService {
    $svc = Get-CimInstance Win32_Service -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -match 'mysql' } |
        Sort-Object Name |
        Select-Object -First 1
    return $svc
}

function Get-MysqlExe {
    param([string]$ServiceName = "")
    if ($ServiceName) {
        $svc = Get-CimInstance Win32_Service -ErrorAction SilentlyContinue | Where-Object { $_.Name -eq $ServiceName }
        if ($svc -and $svc.PathName -match '"([^"]*mysqld\.exe)"') {
            $cand = Join-Path (Split-Path $Matches[1] -Parent) 'mysql.exe'
            if (Test-Path $cand) { return $cand }
        }
    }
    $dirs = @()
    if (Test-Path 'C:\Program Files\MySQL') {
        $dirs += Get-ChildItem 'C:\Program Files\MySQL' -Directory -ErrorAction SilentlyContinue
    }
    if (Test-Path 'C:\Program Files\MariaDB*') {
        $dirs += Get-ChildItem 'C:\Program Files\' -Directory -Filter 'MariaDB*' -ErrorAction SilentlyContinue
    }
    foreach ($d in ($dirs | Sort-Object Name -Descending)) {
        $p = Join-Path $d.FullName 'bin\mysql.exe'
        if (Test-Path $p) { return $p }
    }
    $cmd = Get-Command mysql.exe -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    return $null
}

function Get-MyIniPath {
    param($Service)
    if ($Service -and $Service.PathName -match '--defaults-file="?([^"]+?\.ini)"?') {
        return $Matches[1]
    }
    $found = Get-ChildItem 'C:\ProgramData\MySQL' -Recurse -Filter 'my.ini' -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1
    if ($found) { return $found.FullName }
    return $null
}

function Set-IniKey {
    param(
        [Parameter(Mandatory=$true)][string]$Path,
        [Parameter(Mandatory=$true)][string]$Section,
        [Parameter(Mandatory=$true)][string]$Key,
        [Parameter(Mandatory=$true)][string]$Value
    )
    $lines = @(Get-Content -LiteralPath $Path -Encoding ASCII)
    $result = New-Object 'System.Collections.Generic.List[string]'
    $inSection = $false
    $done = $false
    foreach ($line in $lines) {
        if ($line -match '^\s*\[(.+?)\]\s*$') {
            if ($inSection -and -not $done) { $result.Add("$Key=$Value"); $done = $true }
            $inSection = ($Matches[1].Trim() -ieq $Section)
            $result.Add($line)
            continue
        }
        if ($inSection -and $line -match ('^\s*#?\s*' + [regex]::Escape($Key) + '\s*=')) {
            if (-not $done) { $result.Add("$Key=$Value"); $done = $true }
            continue
        }
        $result.Add($line)
    }
    if ($inSection -and -not $done) { $result.Add("$Key=$Value"); $done = $true }
    if (-not $done) {
        $result.Add("")
        $result.Add("[$Section]")
        $result.Add("$Key=$Value")
    }
    Set-Content -LiteralPath $Path -Value $result -Encoding ASCII
}

function Invoke-MysqlRoot {
    param(
        [Parameter(Mandatory=$true)][string]$MysqlExe,
        [string]$RootPass = "",
        [Parameter(Mandatory=$true)][string[]]$ArgList
    )
    $all = @('-u', 'root')
    if ($RootPass -ne '') { $all += "-p$RootPass" }
    $all += $ArgList
    # In kết quả ra màn hình nhưng KHÔNG đưa vào pipeline (để hàm chỉ trả về exit code)
    & $MysqlExe @all 2>&1 | ForEach-Object { Write-Host "    $_" }
    return $LASTEXITCODE
}

function Wait-MysqlPort {
    param([int]$Port = 3306, [int]$TimeoutSec = 40)
    $deadline = (Get-Date).AddSeconds($TimeoutSec)
    while ((Get-Date) -lt $deadline) {
        $c = New-Object Net.Sockets.TcpClient
        try {
            $c.Connect('127.0.0.1', $Port)
            $c.Close()
            return $true
        } catch {
            Start-Sleep -Seconds 1
        } finally {
            $c.Dispose()
        }
    }
    return $false
}

function Test-TcpPort {
    param([string]$ComputerName, [int]$Port = 3306, [int]$TimeoutMs = 4000)
    $client = New-Object Net.Sockets.TcpClient
    try {
        $iar = $client.BeginConnect($ComputerName, $Port, $null, $null)
        if (-not $iar.AsyncWaitHandle.WaitOne($TimeoutMs, $false)) { return $false }
        $client.EndConnect($iar)
        return $true
    } catch {
        return $false
    } finally {
        $client.Close()
    }
}
