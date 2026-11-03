#!/bin/bash
# =============================================================
#  Cấu hình replication (đồng bộ) tới máy chủ còn lại
#
#  Cách dùng:
#     sudo bash setup_replication.sh <IP_MAY_KIA> [user] [pass]
#
#  Ví dụ:
#     Trên Server 1: sudo bash setup_replication.sh 192.168.1.20
#     Trên Server 2: sudo bash setup_replication.sh 192.168.1.10
# =============================================================
set -e

PEER="${1}"
REPL_USER="${2:-replicator}"
REPL_PASS="${3:-replica123}"

if [ -z "$PEER" ]; then
  echo "Thiếu IP máy chủ còn lại."
  echo "Dùng: sudo bash $0 <IP_MAY_KIA> [user] [pass]"
  exit 1
fi

if [ "$EUID" -ne 0 ]; then
  echo "Hãy chạy bằng sudo: sudo bash $0 $PEER"
  exit 1
fi

echo "==> Kiểm tra kết nối tới ${PEER}:3306 ..."
if ! timeout 5 bash -c "cat < /dev/null > /dev/tcp/${PEER}/3306" 2>/dev/null; then
  echo "    KHÔNG kết nối được tới ${PEER}:3306"
  echo "    - Kiểm tra MySQL trên máy kia đã chạy chưa"
  echo "    - Kiểm tra firewall / bind-address"
  exit 1
fi
echo "    OK"

echo "==> Cấu hình replica trỏ về ${PEER} (GTID auto-position) ..."
mysql << SQL
STOP REPLICA;
RESET REPLICA ALL;
CHANGE REPLICATION SOURCE TO
  SOURCE_HOST='${PEER}',
  SOURCE_PORT=3306,
  SOURCE_USER='${REPL_USER}',
  SOURCE_PASSWORD='${REPL_PASS}',
  SOURCE_AUTO_POSITION=1,
  SOURCE_SSL=1,
  SOURCE_CONNECT_RETRY=10,
  SOURCE_RETRY_COUNT=86400;
START REPLICA;
SQL

sleep 3
echo "==> Trạng thái:"
mysql -e "SHOW REPLICA STATUS\G" | grep -E \
  "Replica_IO_Running|Replica_SQL_Running|Seconds_Behind_Source|Last_IO_Error|Last_SQL_Error" || true

echo
echo "Nếu Replica_IO_Running = Yes và Replica_SQL_Running = Yes => đồng bộ đã hoạt động."
echo "Nếu = Connecting: kiểm tra IP, user replicator, mật khẩu, firewall."
