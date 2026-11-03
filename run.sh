#!/bin/bash
# ============================================================
#  Chạy ứng dụng trên Linux
#  Yêu cầu: JDK 17+ (có javac trong PATH)
#
#  Cách dùng:
#     ./run.sh             -> dùng config.properties hiện có
#     ./run.sh client1     -> máy của bạn
#     ./run.sh client2     -> máy bạn bè
#     ./run.sh server1     -> chạy trên Server 1
#     ./run.sh server2     -> chạy trên Server 2
# ============================================================
cd "$(dirname "$0")" || exit 1

ROLE="$1"
if [ -n "$ROLE" ]; then
  if [ -f "configs/${ROLE}.properties" ]; then
    cp "configs/${ROLE}.properties" config.properties
    echo "[CFG] configs/${ROLE}.properties -> config.properties"
    grep -E '^(ROLE|CLIENT_ID|lockManager.host)=' config.properties | sed 's/^/      /'
  else
    echo "Vai trò không hợp lệ: $ROLE"
    echo "Dùng: ./run.sh [client1|client2|server1|server2|desktop_server1_client1|vm_client2|vm_server2]"
    exit 1
  fi
fi

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
