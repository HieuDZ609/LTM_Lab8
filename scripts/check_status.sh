#!/bin/bash
# ============================================================
#  Kiểm tra nhanh trạng thái hệ thống trên máy đang chạy
# ============================================================
cd "$(dirname "$0")/.." 2>/dev/null || true

# Cho phép dùng cả mysql (appuser) và sudo mysql (root)
MYSQL_APP="mysql -u appuser -papp123 shared_records"
if ! $MYSQL_APP -e "SELECT 1" >/dev/null 2>&1; then
  MYSQL_APP="sudo mysql shared_records"
fi
MYSQL_ROOT="mysql -e"
if ! $MYSQL_ROOT "SELECT 1" >/dev/null 2>&1; then
  MYSQL_ROOT="sudo mysql -e"
fi

echo "================ IP MÁY NÀY ================"
hostname -I

echo
echo "================ MYSQL ================"
systemctl is-active mysql 2>/dev/null || echo "mysql: không chạy"

echo
echo "================ BẢN GHI ================"
$MYSQL_APP -e "SELECT record_id, record_code, record_name, created_at FROM records ORDER BY record_id;" 2>/dev/null

echo
echo "================ KHÓA ĐANG GIỮ ================"
$MYSQL_APP -e "SELECT l.record_id, r.record_code, l.client_id, l.expires_at,
       IF(l.expires_at > NOW(),'CÒN HIỆU LỰC','HẾT HẠN') AS trang_thai
  FROM record_locks l LEFT JOIN records r ON r.record_id = l.record_id;" 2>/dev/null \
  || echo "(không có khóa nào)"

echo
echo "================ REPLICATION ================"
OUT=$($MYSQL_ROOT "SHOW REPLICA STATUS\G" 2>/dev/null)
if [ -z "$OUT" ]; then
  echo "Máy này chưa cấu hình replica (bình thường nếu là Server 1 chưa nối Server 2)"
else
  echo "$OUT" | grep -E "Source_Host|Replica_IO_Running|Replica_SQL_Running|Seconds_Behind_Source|Last_IO_Error|Last_SQL_Error"
fi
