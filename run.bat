@echo off
REM ============================================
REM  Chay ung dung tren Windows
REM  Yeu cau: da cai JDK 17+ (java + javac trong PATH)
REM ============================================
cd /d "%~dp0"

if not exist out mkdir out

echo [1/2] Dang bien dich...
javac -encoding UTF-8 -cp "lib\mysql-connector-j-8.4.0.jar" -d out src\com\ltm\Main.java src\com\ltm\db\DBConnection.java src\com\ltm\model\Record.java src\com\ltm\model\RecordLock.java src\com\ltm\service\RecordService.java src\com\ltm\ui\MainFrame.java
if errorlevel 1 (
    echo Bien dich that bai. Kiem tra JDK da cai chua.
    pause
    exit /b 1
)

echo [2/2] Dang chay ung dung...
java -cp "out;lib\mysql-connector-j-8.4.0.jar;." com.ltm.Main
pause
