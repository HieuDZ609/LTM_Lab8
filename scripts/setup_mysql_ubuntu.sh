#!/bin/bash
# =============================================================
#  Cài đặt MySQL Server cho mô hình Đồng bộ CSDL 2 Server
#  Dùng cho Ubuntu/Debian (Server 1 hoặc Server 2)
#
#  Cách dùng:
#     sudo bash setup_mysql_ubuntu.sh <SERVER_ID>
#  Ví dụ:
#     sudo bash setup_mysql_ubuntu.sh 2      # cho Server 2
# =============================================================
set -e

SERVER_ID="${1:-2}"
DB_NAME="shared_records"
APP_USER="appuser"
APP_PASS="app123"
REPL_USER="replicator"
REPL_PASS="replica123"

if [ "$EUID" -ne 0 ]; then
  echo "Hãy chạy bằng sudo: sudo bash $0 $SERVER_ID"
  exit 1
fi

echo "==> [1/6] Cài MySQL Server..."
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq mysql-server

echo "==> [2/6] Cấu hình bind-address + GTID + server-id=$SERVER_ID..."
CONF="/etc/mysql/mysql.conf.d/mysqld.cnf"
sed -i "s/^bind-address.*/bind-address = 0.0.0.0/" "$CONF"
sed -i "s/^mysqlx-bind-address.*/mysqlx-bind-address = 0.0.0.0/" "$CONF"

# Xóa cấu hình cũ do script này thêm (nếu chạy lại)
sed -i '/^# === LTM SYNC BEGIN ===$/,/^# === LTM SYNC END ===$/d' "$CONF"

cat >> "$CONF" << EOF
# === LTM SYNC BEGIN ===
server-id               = ${SERVER_ID}
log_bin                 = mysql-bin
binlog_format           = ROW
gtid_mode               = ON
enforce_gtid_consistency = ON
log_replica_updates     = ON
relay_log               = relay-bin
# === LTM SYNC END ===
EOF

systemctl restart mysql
sleep 3

echo "==> [3/6] Tạo database, bảng và user..."
mysql << SQL
CREATE DATABASE IF NOT EXISTS ${DB_NAME} CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE ${DB_NAME};

CREATE TABLE IF NOT EXISTS records (
  record_id   BIGINT AUTO_INCREMENT PRIMARY KEY,
  record_code VARCHAR(50)  NOT NULL,
  record_name VARCHAR(150) NOT NULL,
  created_at  TIMESTAMP    DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT uq_record_code UNIQUE (record_code)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS record_locks (
  record_id   BIGINT      PRIMARY KEY,
  client_id   VARCHAR(50) NOT NULL,
  lock_token  CHAR(36)    NOT NULL,
  locked_at   TIMESTAMP   DEFAULT CURRENT_TIMESTAMP,
  expires_at  TIMESTAMP   NOT NULL,
  CONSTRAINT fk_lock_record FOREIGN KEY (record_id)
      REFERENCES records(record_id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE USER IF NOT EXISTS '${APP_USER}'@'%' IDENTIFIED WITH caching_sha2_password BY '${APP_PASS}';
ALTER USER '${APP_USER}'@'%' IDENTIFIED WITH caching_sha2_password BY '${APP_PASS}';
GRANT SELECT, INSERT, UPDATE, DELETE ON ${DB_NAME}.* TO '${APP_USER}'@'%';

CREATE USER IF NOT EXISTS '${REPL_USER}'@'%' IDENTIFIED WITH caching_sha2_password BY '${REPL_PASS}';
ALTER USER '${REPL_USER}'@'%' IDENTIFIED WITH caching_sha2_password BY '${REPL_PASS}';
ALTER USER '${REPL_USER}'@'%' REQUIRE SSL;
GRANT REPLICATION SLAVE ON *.* TO '${REPL_USER}'@'%';

FLUSH PRIVILEGES;
SQL

echo "==> [4/6] Mở firewall (nếu có ufw)..."
if command -v ufw >/dev/null 2>&1; then
  ufw allow 3306/tcp >/dev/null 2>&1 || true
  echo "    Đã mở cổng 3306/tcp"
fi

echo "==> [5/6] Kiểm tra..."
mysql -e "SHOW VARIABLES LIKE 'server_id'; SHOW VARIABLES LIKE 'bind_address';"
mysql -e "SHOW VARIABLES LIKE 'gtid_mode';"

echo "==> [6/6] Thông tin kết nối:"
IP=$(hostname -I | awk '{print $1}')
echo "    IP máy này : ${IP}"
echo "    Database   : ${DB_NAME}"
echo "    App user   : ${APP_USER} / ${APP_PASS}"
echo "    Repl user  : ${REPL_USER} / ${REPL_PASS}"
echo
echo "BƯỚC TIẾP THEO:"
echo "  Trên máy này chạy:"
echo "    sudo bash setup_replication.sh <IP_MAY_CHỦ_KIA>"
echo
echo "  Rồi sửa config.properties: server1.host / lockManager.host = IP Server 1"
