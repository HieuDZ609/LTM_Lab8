# 04 — XỬ LÝ LỖI THƯỜNG GẶP

## 1. Lỗi kết nối

### `Can't connect to MySQL server on '...' (113)`

| Nguyên nhân | Cách kiểm tra | Cách sửa |
|---|---|---|
| MySQL không chạy | `systemctl is-active mysql` | `sudo systemctl start mysql` |
| `bind-address = 127.0.0.1` | `mysql -e "SHOW VARIABLES LIKE 'bind_address';"` | Sửa thành `0.0.0.0`, restart |
| Firewall chặn | `sudo ufw status` | `sudo ufw allow 3306/tcp` |
| Sai IP | `hostname -I` | Cập nhật `config.properties` |

### `Access denied for user 'appuser'@'...'`

```bash
# Kiểm tra user tồn tại
mysql -e "SELECT user, host FROM mysql.user WHERE user='appuser';"
```

Nếu `host` là `localhost` thay vì `%`:

```sql
CREATE USER 'appuser'@'%' IDENTIFIED BY 'app123';
GRANT SELECT,INSERT,UPDATE,DELETE ON shared_records.* TO 'appuser'@'%';
FLUSH PRIVILEGES;
```

### `Authentication plugin 'caching_sha2_password' ... requires secure connection`

MySQL 8 mặc định yêu cầu TLS cho `caching_sha2_password`. Trong `config.properties` đã bật `allowPublicKeyRetrieval=true` nên app thường không gặp lỗi này. Nếu vẫn gặp khi cấu hình replication:

```sql
ALTER USER 'replicator'@'%' REQUIRE SSL;
```

Và dùng `SOURCE_SSL=1` (script `setup_replication.sh` đã làm sẵn).

### `Public Key Retrieval is not allowed`

URL JDBC đã có `allowPublicKeyRetrieval=true`. Nếu tự viết URL, phải thêm tham số này.

---

## 2. Lỗi replication

### `Replica_IO_Running: Connecting` (mãi không chuyển Yes)

```bash
mysql -e "SHOW REPLICA STATUS\G" | grep -E "Last_IO_Error|Source_Host"
```

| `Last_IO_Error` | Nguyên nhân | Cách sửa |
|---|---|---|
| `Can't connect to MySQL server` | Sai IP / firewall / MySQL tắt | Kiểm tra `nc -zv IP 3306` |
| `Access denied for user 'replicator'` | Sai mật khẩu hoặc thiếu `REPLICATION SLAVE` | Chạy lại `setup_mysql_ubuntu.sh` |
| `Authentication requires secure connection` | Thiếu SSL | `ALTER USER 'replicator'@'%' REQUIRE SSL;` và `SOURCE_SSL=1` |
| `The server is not configured as slave` (không có) | — | — |
| `Unknown system variable` | MySQL cũ (< 8.0.23) | Dùng `CHANGE MASTER TO` thay `CHANGE REPLICATION SOURCE TO` |

### `Replica_SQL_Running: No`

```bash
mysql -e "SHOW REPLICA STATUS\G" | grep -E "Last_SQL_Error|Last_Errno"
```

| Lỗi | Nguyên nhân | Cách sửa |
|---|---|---|
| `Duplicate entry` | Cả hai server từng nhận cùng INSERT (master-master thuần) | Bỏ qua giao dịch: `SET GLOBAL sql_replica_skip_counter = 1;` hoặc dùng GTID `SET GTID_NEXT='...'; BEGIN; COMMIT; SET GTID_NEXT='AUTOMATIC';` |
| `Table ... doesn't exist` | Bảng chưa tạo trên server nhận | Chạy `sql/init_shared_records.sql` |
| `Unknown database` | Chưa tạo database | Như trên |

### Cách thiết lập lại replication từ đầu

```bash
# Trên máy nhận
mysql -e "STOP REPLICA; RESET REPLICA ALL;"
sudo bash scripts/setup_replication.sh <IP_MAY_KIA>
```

### Kiểm tra GTID có bật chưa

```bash
mysql -e "SHOW VARIABLES LIKE 'gtid_mode';"          # phải là ON
mysql -e "SHOW VARIABLES LIKE 'log_replica_updates';" # phải là ON
```

Nếu `gtid_mode` khác ON, phải bật theo đúng thứ tự:

```sql
SET @@GLOBAL.enforce_gtid_consistency = WARN;
SET @@GLOBAL.enforce_gtid_consistency = ON;
SET @@GLOBAL.gtid_mode = OFF_PERMISSIVE;
SET @@GLOBAL.gtid_mode = ON_PERMISSIVE;
SET @@GLOBAL.gtid_mode = ON;
```

---

## 3. Lỗi ứng dụng

### `Không tìm thấy MySQL Connector/J trong classpath!`

File `lib/mysql-connector-j-8.4.0.jar` chưa có hoặc chạy sai thư mục.

```bash
ls -l lib/mysql-connector-j-8.4.0.jar   # phải tồn tại
./run.sh                                 # run.sh tự cd vào thư mục dự án
```

### `Chưa điền IP thật cho server2.host (đang là IP_MAY_BAN_BE)`

Đây là **thông báo có chủ đích**. Mở `config.properties` và thay IP thật.

### App treo vài chục giây khi mở

Đã xử lý bằng `connectTimeout=3000&socketTimeout=5000`. Nếu vẫn chậm, kiểm tra DNS: dùng IP thay vì hostname.

### `javac: command not found`

```bash
# Ubuntu
sudo apt install default-jdk
# Kiểm tra
javac -version
```

### `Could not find or load main class com.ltm.Main`

Chưa biên dịch. Chạy lại `./run.sh`, hoặc:

```bash
mkdir -p out
javac -encoding UTF-8 -cp lib/mysql-connector-j-8.4.0.jar -d out $(find src -name '*.java')
```

### Giao diện hiện ô vuông thay vì tiếng Việt

Thiếu font. Cài:

```bash
sudo apt install fonts-noto fonts-dejavu
```

Hoặc chạy với locale UTF-8:

```bash
LANG=vi_VN.UTF-8 ./run.sh
```

---

## 4. Lỗi logic

### Không khóa được dù hiển thị "Rảnh"

Khóa cũ đã hết hạn nhưng chưa bị dọn. Ứng dụng dọn tự động trước mỗi lần khóa, nhưng nếu gọi SQL trực tiếp:

```sql
DELETE FROM record_locks WHERE expires_at < NOW();
```

### Khóa tồn tại mãi không tự mất

Kiểm tra `expires_at` so với giờ hệ thống. Lệch múi giờ giữa 2 server gây sai:

```bash
timedatectl                          # kiểm tra timezone
sudo timedatectl set-timezone Asia/Ho_Chi_Minh
```

### Đã giải phóng nhưng báo "Token không đúng"

- `client_id` khác với lúc khóa
- Token bị copy thiếu ký tự
- Khóa đã bị dọn do hết hạn

Kiểm tra:

```sql
SELECT * FROM record_locks WHERE record_id = <ID>;
```

### Hai client cùng khóa được (vi phạm yêu cầu)

Nguyên nhân: `lockManager.host` khác nhau trên 2 máy. Kiểm tra:

```bash
grep lockManager.host config.properties
```

Phải **giống hệt nhau** trên cả 4 máy.

---

## 5. Lỗi VMware / mạng

### Máy ảo không ping được máy thật

1. VMware → Settings → Network Adapter → **Bridged**
2. Trong Ubuntu: `ip a` xem có IP cùng dải máy thật không
3. Nếu không: `sudo dhclient -r && sudo dhclient`

### Máy thật ping được máy ảo nhưng ngược lại không

Kiểm tra card `vmnet8` (NAT) đang bật trên máy thật:

```bash
ip -4 addr show vmnet8
```

### IP thay đổi sau mỗi lần khởi động (DHCP)

Đặt IP tĩnh:

```bash
sudo nano /etc/netplan/01-netcfg.yaml
```

```yaml
network:
  version: 2
  ethernets:
    ens33:
      dhcp4: no
      addresses: [192.168.100.144/24]
      routes:
        - to: default
          via: 192.168.100.1
      nameservers:
        addresses: [8.8.8.8]
```

```bash
sudo netplan apply
```

---

## 6. Lệnh kiểm tra nhanh

```bash
# Toàn bộ trạng thái hệ thống
bash scripts/check_status.sh

# Replication
mysql -e "SHOW REPLICA STATUS\G" | grep -E "Running|Error|Behind"

# Khóa đang giữ
mysql shared_records -e "SELECT l.*, r.record_code FROM record_locks l
  JOIN records r ON r.record_id=l.record_id;"

# Bản ghi 2 bên
mysql shared_records -e "SELECT COUNT(*) FROM records;"
mysql -h <IP_SERVER_2> -u appuser -papp123 shared_records -e "SELECT COUNT(*) FROM records;"

# Log MySQL
sudo journalctl -u mysql -n 50 --no-pager
sudo tail -50 /var/log/mysql/error.log
```
