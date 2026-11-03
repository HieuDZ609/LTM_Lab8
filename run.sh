#!/bin/bash
# ============================================================
#  Chạy ứng dụng trên Linux
#  Yêu cầu: JDK 17+ (có javac trong PATH)
# ============================================================
cd "$(dirname "$0")" || exit 1

if ! command -v javac >/dev/null 2>&1; then
  echo "Chưa có JDK. Cài bằng:  sudo apt install default-jdk"
  exit 1
fi

if [ ! -f "lib/mysql-connector-j-8.4.0.jar" ]; then
  echo "Thiếu lib/mysql-connector-j-8.4.0.jar"
  exit 1
fi

mkdir -p out

echo "[1/2] Biên dịch..."
javac -encoding UTF-8 -cp "lib/mysql-connector-j-8.4.0.jar" -d out $(find src -name "*.java")
if [ $? -ne 0 ]; then
  echo "Biên dịch thất bại."
  exit 1
fi

echo "[2/2] Chạy ứng dụng..."
java -Dfile.encoding=UTF-8 -cp "out:lib/mysql-connector-j-8.4.0.jar:." com.ltm.Main
