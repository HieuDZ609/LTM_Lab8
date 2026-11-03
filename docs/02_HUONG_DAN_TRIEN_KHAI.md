# 02 — HƯỚNG DẪN TRIỂN KHAI TỪNG BƯỚC

Tài liệu này hướng dẫn triển khai trên **4 máy**:

| Máy | Vai trò | IP |
|---|---|---|
| Client 1 | Java Swing (máy bạn) | `172.26.40.121` |
| Server 1 | MySQL + Lock Manager (VMware máy bạn) | `172.16.228.141` |
| Client 2 | Java Swing (máy bạn bè, Windows) | `172.26.82.95` |
| Server 2 | MySQL replica (VMware máy bạn bè) | `192.168.161.131` |

> Thay các IP trên bằng IP thật nếu DHCP đổi. Lấy IP bằng `hostname -I` (Linux) hoặc `ipconfig` (Windows).
> Windows: xem riêng [`05_HUONG_DAN_WINDOWS.md`](05_HUONG_DAN_WINDOWS.md).

---

## GIAI ĐOẠN 1 — KIỂM TRA MẠNG

Trên **mỗi máy**, chạy:

```bash
hostname -I
ping <IP_MAY_KHAC>
```

Yêu cầu: **tất cả 4 máy ping được nhau**.

Nếu máy ảo VMware không ping được máy thật:

1. VMware → `VM` → `Settings` → `Network Adapter`
2. Chọn **Bridged** (khuyến nghị) hoặc **NAT**
3. Nếu Bridged: máy ảo nhận IP cùng dải với máy thật
4. Nếu NAT: máy ảo ở dải `172.16.x.x`, máy thật có card `vmnet8`

Kiểm tra cổng MySQL (sau khi cài):

```bash
nc -zv <IP_SERVER> 3306
```

---

## GIAI ĐOẠN 2 — CÀI MYSQL TRÊN 2 SERVER

### Server 1 (Ubuntu)

```bash
cd DeTai_SyncDB_2Server_2Client
sudo bash scripts/setup_mysql_ubuntu.sh 1
```

### Server 2 (Ubuntu)

```bash
sudo bash scripts/setup_mysql_ubuntu.sh 2
```

Script thực hiện:

1. Cài `mysql-server`
2. Đặt `bind-address = 0.0.0.0` (cho phép kết nối từ xa)
3. Bật GTID + binlog
4. Tạo database `shared_records`, 2 bảng, 2 user
5. Mở firewall cổng 3306

### Nếu Server 2 chạy Windows (máy bạn bè)

> Hướng dẫn đầy đủ (cài JDK, MySQL Installer, firewall, lỗi thường gặp):
> **[`05_HUONG_DAN_WINDOWS.md`](05_HUONG_DAN_WINDOWS.md)**

Tóm tắt:

1. Cài **JDK 21** (<https://adoptium.net>) và **MySQL Server 8.4** (MySQL Installer, port 3306, root password).
2. Mở **PowerShell (Run as administrator)** tại thư mục dự án:

```powershell
Set-ExecutionPolicy -Scope Process Bypass -Force
.\scripts\setup_mysql_windows.ps1 -ServerId 2 -RootPass "mat_khau_root"
```

Script tự làm: sao lưu `my.ini`, bật GTID + binlog + `log_replica_updates`, `bind-address=0.0.0.0`, tạo DB/bảng/user, mở firewall 3306.

Nếu muốn làm tay, thêm dưới `[mysqld]` trong `C:\ProgramData\MySQL\MySQL Server 8.4\my.ini`:

```ini
bind-address = 0.0.0.0
server-id = 2
log_bin = mysql-bin
binlog_format = ROW
gtid_mode = ON
enforce_gtid_consistency = ON
log_replica_updates = ON
```

rồi `net stop MySQL84 && net start MySQL84`, chạy `sql/init_shared_records.sql`, và mở firewall:

```cmd
netsh advfirewall firewall add rule name="MySQL 3306" dir=in action=allow protocol=TCP localport=3306
```

---

## GIAI ĐOẠN 3 — KIỂM TRA KẾT NỐI CHÉO

Từ **Server 1**:

```bash
mysql -h <IP_SERVER_2> -u appuser -papp123 -e "SELECT 1;"
```

Từ **Server 2**:

```bash
mysql -h <IP_SERVER_1> -u appuser -papp123 -e "SELECT 1;"
```

Cả hai phải trả về `1`.

Nếu lỗi:

| Thông báo | Nguyên nhân | Cách sửa |
|---|---|---|
| `Can't connect ... (113)` | Firewall / MySQL không chạy | Mở cổng 3306, `systemctl start mysql` |
| `Access denied for user` | Sai mật khẩu hoặc user chưa có | Chạy lại `setup_mysql_ubuntu.sh` |
| `Host is not allowed` | User chỉ cho `localhost` | Tạo lại user với `'%'` |

---

## GIAI ĐOẠN 4 — BẬT ĐỒNG BỘ HAI CHIỀU

### Trên Server 1 (Ubuntu)

```bash
sudo bash scripts/setup_replication.sh 192.168.161.131
```

### Trên Server 2 (Windows — máy bạn bè)

```powershell
Set-ExecutionPolicy -Scope Process Bypass -Force
.\scripts\setup_replication_windows.ps1 -PeerHost 172.16.228.141 -RootPass "mat_khau_root"
```

### Trên Server 2 nếu dùng Ubuntu

```bash
sudo bash scripts/setup_replication.sh 172.16.228.141
```

### Kiểm tra

Trên **cả hai** máy:

```bash
mysql -e "SHOW REPLICA STATUS\G" | grep -E "Replica_IO_Running|Replica_SQL_Running"
```

Kết quả đúng:

```
Replica_IO_Running: Yes
Replica_SQL_Running: Yes
```

### Kiểm tra đồng bộ thực tế

Trên **Server 1**:

```bash
mysql shared_records -e "INSERT INTO records (record_code, record_name) VALUES ('TEST01','Kiem tra dong bo');"
```

Đợi 2 giây, trên **Server 2**:

```bash
mysql shared_records -e "SELECT * FROM records WHERE record_code='TEST01';"
```

Phải thấy bản ghi. Sau đó xoá:

```bash
mysql shared_records -e "DELETE FROM records WHERE record_code='TEST01';"
```

---

## GIAI ĐOẠN 5 — CẤU HÌNH ỨNG DỤNG

### Server 1

```bash
cp configs/server1.properties config.properties
nano config.properties
```

Sửa:

```properties
ROLE=SERVER1
CLIENT_ID=SERVER-1
server1.host=172.16.228.141
server2.host=192.168.161.131
lockManager.host=172.16.228.141
```

### Server 2

```bash
cp configs/server2.properties config.properties
```

```properties
ROLE=SERVER2
CLIENT_ID=SERVER-2
server1.host=172.16.228.141
server2.host=192.168.161.131
lockManager.host=172.16.228.141
```

### Client 1 (máy của bạn)

```bash
cp configs/client1.properties config.properties
```

```properties
ROLE=CLIENT1
CLIENT_ID=CLIENT-1
server2.host=192.168.161.131
lockManager.host=172.16.228.141
```

### Client 2 (máy bạn bè, Windows)

```cmd
run.bat client2
```

```properties
ROLE=CLIENT2
CLIENT_ID=CLIENT-2
server1.host=172.16.228.141
server2.host=192.168.161.131
lockManager.host=172.16.228.141
```

> **Điểm mấu chốt**: `lockManager.host` phải **giống nhau trên cả 4 máy** và luôn trỏ về Server 1. Đây là điều đảm bảo hai Client không bao giờ cùng được cấp khóa.

---

## GIAI ĐOẠN 6 — CHẠY ỨNG DỤNG

### Linux

```bash
chmod +x run.sh
./run.sh
```

### Windows

```cmd
run.bat client2
```

hoặc nhấp đúp **`chay_client2.bat`**. Chạy app ngay trên Server 2: `run.bat server2`.

### Kiểm tra giao diện

1. Tab **3. Đồng bộ & Kết nối** → `Kiểm tra kết nối`
   - Server 1 (Lock Manager): **OK** màu xanh
   - Server 2: **OK** màu xanh
2. `Kiểm tra đồng bộ` → phải hiện **ĐÃ ĐỒNG BỘ**

---

## GIAI ĐOẠN 7 — DEMO

Mở app trên **Client 1** và **Client 2** (2 máy khác nhau).

### Demo 1: Đồng bộ

1. Client 1 → Tab 1 → `Tạo bản ghi mới` → `SV010` / `Nguyen Van X`
2. Đợi 2 giây
3. Client 2 → Tab 1 → `Tải lại danh sách`
4. → Thấy `SV010` xuất hiện

### Demo 2: Chống trùng

1. Client 1 tạo `SV020`
2. Client 2 tạo `SV020`
3. → Client 2 nhận: **`Mã bản ghi 'SV020' đã tồn tại (vi phạm UNIQUE)`**

### Demo 3: Khóa bản ghi

1. Client 1 → Tab 2 → chọn `SV010` → `KHÓA BẢN GHI`
2. → Nhận `LOCK_TOKEN`
3. Client 2 → Tab 1 → `Tải lại` → `SV010` hiện **ĐANG DÙNG bởi CLIENT-1**
4. Client 2 → Tab 2 → chọn `SV010` → `KHÓA`
5. → Nhận: **`Bản ghi đang được sử dụng bởi CLIENT-1 (...)`**

### Demo 4: Giải phóng

1. Client 1 → Tab 2 (phải) → token đã tự điền → `GIẢI PHÓNG`
2. Client 2 → Tab 2 → `KHÓA` lại `SV010`
3. → **Thành công**, Client 2 nhận token mới

### Demo 5: Token sai

1. Client 1 đang giữ `SV030`
2. Client 2 nhập token bất kỳ → `GIẢI PHÓNG`
3. → **`Token không đúng hoặc bạn không phải chủ sở hữu khóa`**
4. Client 1 vẫn giữ khóa

---

## CHECKLIST HOÀN THÀNH

- [ ] 4 máy ping được nhau
- [ ] MySQL chạy trên cả 2 server
- [ ] Kết nối chéo `appuser` thành công
- [ ] `Replica_IO_Running = Yes` trên cả 2 server
- [ ] Tạo ở Server 1 → thấy ở Server 2
- [ ] Tạo ở Server 2 → thấy ở Server 1
- [ ] App hiển thị `ĐÃ ĐỒNG BỘ`
- [ ] Tạo trùng → báo lỗi
- [ ] Khóa chéo → báo "đang được sử dụng"
- [ ] Giải phóng đúng token → thành công
- [ ] Giải phóng sai token → bị từ chối
