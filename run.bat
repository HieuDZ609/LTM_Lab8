@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion
cd /d "%~dp0"

REM ============================================================
REM  Chay ung dung (Windows)
REM  Yeu cau: JDK 17+ (java + javac trong PATH)
REM
REM  Cach dung:
REM     run.bat              -> dung config.properties hien co
REM     run.bat client1      -> may cua ban
REM     run.bat client2      -> may ban be
REM     run.bat server1      -> chay ngay tren Server 1
REM     run.bat server2      -> chay ngay tren Server 2
REM ============================================================

set "ROLE=%~1"
if "%ROLE%"=="" goto :compile

if /I "%ROLE%"=="client1"  set "CFG=configs\client1.properties"
if /I "%ROLE%"=="client2"  set "CFG=configs\client2.properties"
if /I "%ROLE%"=="server1"  set "CFG=configs\server1.properties"
if /I "%ROLE%"=="server2"  set "CFG=configs\server2.properties"
if /I "%ROLE%"=="desktop"  set "CFG=configs\desktop_server1_client1.properties"

if not defined CFG (
    echo Vai tro khong hop le: %ROLE%
    echo Dung: run.bat [client1^|client2^|server1^|server2^|desktop]
    pause
    exit /b 1
)

copy /Y "%CFG%" config.properties >nul
if errorlevel 1 (
    echo Khong copy duoc %CFG%
    pause
    exit /b 1
)
echo [CFG] %CFG%  -^>  config.properties
for /f "tokens=1,2 delims==" %%a in ('findstr /B "ROLE= CLIENT_ID= lockManager.host=" config.properties') do echo       %%a=%%b
echo.

:compile
where javac >nul 2>&1
if errorlevel 1 (
    echo [LOI] Chua co JDK. Tai JDK 17/21 tai: https://adoptium.net
    echo       Sau khi cai, mo cmd moi va chay lai.
    pause
    exit /b 1
)

if not exist out mkdir out
if not exist lib\mysql-connector-j-8.4.0.jar (
    echo [LOI] Thieu lib\mysql-connector-j-8.4.0.jar
    pause
    exit /b 1
)

echo [1/2] Bien dich...
dir /s /b src\*.java > sources.txt
javac -encoding UTF-8 -cp "lib\mysql-connector-j-8.4.0.jar" -d out @sources.txt
set "RC=%ERRORLEVEL%"
del /q sources.txt >nul 2>&1
if not "%RC%"=="0" (
    echo [LOI] Bien dich that bai.
    pause
    exit /b 1
)

echo [2/2] Chay ung dung...
java -Dfile.encoding=UTF-8 -cp "out;lib\mysql-connector-j-8.4.0.jar;." com.ltm.Main
pause
