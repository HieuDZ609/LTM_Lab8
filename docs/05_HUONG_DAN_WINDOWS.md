# 05 — HƯỚNG DẪN CHẠY TRÊN WINDOWS (MÁY BẠN BÈ)

Tài liệu dành cho **máy bạn bè**: vừa là **Client 2**, vừa chạy **Server 2** trong VMware.

---

## 0. THÔNG TIN 4 MÁY

| Máy | Vai trò | IP | Ai chạy |
|---|---|---|---|
| **Client 1** | App Java Swing | `172.26.40.121` (Wi-Fi `VKU_Student` của bạn) | Bạn |
| **Server 1** | MySQL + **Lock Manager** | `172.16.228.141` (VMware trên máy bạn) | Bạn |
| **Client 2** | App Java Swing | `172.26.82.95` (Wi-Fi `VKU_Student` của bạn bè) | Bạn bè |
| **Server 2** | MySQL (nhận đồng bộ) | `192.168.161.131` (VMware trên máy bạn bè) | Bạn bè |

- `lockManager.host` **luôn = IP Server 1** trên cả 4 máy. Đây là quy tắc quan trọng nhất.
- IP Wi-Fi là DHCP, có thể đổi sau khi restart. Kiểm tra lại bằng `ipconfig` (Windows) hoặc `hostname -I` (Linux).

---

## 1. ⚠️ ĐỌC TRƯỚC — VMware NAT và địa chỉ IP

`172.16.228.141` và `192.168.161.131` là IP **bên trong mạng NAT của VMware**, chỉ tồn tại trên chính máy chủ của nó:

```
Máy bạn                        Máy bạn bè
┌─────────────────────┐        ┌─────────────────────┐
│ Wi-Fi 172.26.40.121 │        │ Wi-Fi 172.26.82.95  │
│   └ vmnet8 (NAT)    │   X    │   └ vmnet8 (NAT)    │
│      172.16.228.141 │        │   192.168.161.131   │
└─────────────────────┘        └─────────────────────┘
        Không ping chéo được nếu để NAT
```

Nghĩa là: máy bạn bè **không thể** kết nối trực tiếp tới `172.16.228.141`, và ngược lại. Có 2 cách xử lý, chọn **một**:

### Cách A (KHUYẾN NGHỊ) — Chuyển card mạng VM sang Bridged

Làm trên **cả 2 máy**:

1. Tắt máy ảo.
2. VMware → chọn VM → `Edit virtual machine settings` → `Network Adapter`.
3. Chọn **Bridged** → tick `Replicate physical connection state` → OK.
4. Bật VM, lấy IP mới:

```bash
# Ubuntu
hostname -I
# Windows
ipconfig
```

5. Máy ảo sẽ nhận IP dạng `172.26.x.x` cùng dải Wi-Fi. Cập nhật lại IP trong config:

| File | Sửa gì |
|---|---|
| `configs/server1.properties` | `server1.host` = IP mới Server 1 |
| `configs/client1.properties` | `server1.host`, `lockManager.host` = IP mới Server 1; `server2.host` = IP mới Server 2 |
| `configs/server2.properties` | `server2.host` = IP mới Server 2; `lockManager.host` = IP mới Server 1 |
| `configs/client2.properties` | `lockManager.host` = IP mới Server 1; `server2.host` = IP mới Server 2 |

> Đây là cách ít lỗi nhất. NAT của VMware hay chặn ping/3306 chéo máy.

### Cách B — Giữ NAT, dùng port forwarding

Trên **mỗi máy**, mở VMware → `Edit` → `Virtual Network Editor` → `Change Settings` (cần quyền admin) → chọn `VMnet8 (NAT)` → `NAT Settings` → `Add`:

| Host port | IP máy ảo | VM port | Ý nghĩa |
|---|---|---|---|
| `3307` | `172.16.228.141` | `3306` | trên máy bạn |
| `3307` | `192.168.161.131` | `3306` | trên máy bạn bè |

Sau đó địa chỉ dùng để kết nối chéo là **IP Wi-Fi + cổng 3307**:

| Từ đâu | Tới đâu | Ghi vào config |
|---|---|---|
| Client 2 (bạn bè) | Server 1 (bạn) | `lockManager.host=172.26.40.121`, `lockManager.port=3307` |
| Client 1 (bạn) | Server 2 (bạn bè) | `server2.host=172.26.82.95`, `server2.port=3307` |
| Server 1 (bạn) | Server 2 (bạn bè) | replication `-PeerHost 172.26.82.95 -PeerPort 3307` |
| Server 2 (bạn bè) | Server 1 (bạn) | replication `-PeerHost 172.26.40.121 -PeerPort 3307` |

Đồng thời phải mở firewall cổng 3307 trên **máy thật** (không phải trong VM).

---

## 2. CÀI JDK (Java 17 hoặc 21)

1. Tải **Eclipse Temurin JDK 21 (x64 MSI)**: <https://adoptium.net>
2. Cài, giữ nguyên tuỳ chọn "Set JAVA_HOME variable" và "Add to PATH".
3. Mở **cmd mới** và kiểm tra:

```cmd
java -version
javac -version
```

Phải hiện `javac 21.x`. Nếu báo `'javac' is not recognized`, cài lại và chọn thêm PATH, hoặc thêm thủ công `C:\Program Files\Eclipse Adoptium\jdk-21...\bin` vào `Path`.

---

## 3. CÀI MySQL SERVER 8.4

1. Tải **MySQL Installer (Community)** tại <https://dev.mysql.com/downloads/installer/>.
2. Chạy → chọn **Custom** → thêm **MySQL Server 8.4** → Next → Execute.
3. Ở bước **Type and Networking**:
   - Config Type: **Server Computer**
   - Port: **3306**
   - Tick `Open Windows Firewall ports for network access`
4. **Authentication Method**: chọn **Use Strong Password Encryption** (`caching_sha2_password`).
5. **Accounts and Roles**: đặt **root password** (nhớ kỹ, ví dụ `070995`).
6. **Windows Service**: tên `MySQL84`, tick **Start the MySQL Server at System Startup**.
7. Apply Configuration → Finish.

Kiểm tra:

```cmd
sc query MySQL84
"C:\Program Files\MySQL\MySQL Server 8.4\bin\mysql.exe" -u root -p -e "SELECT VERSION();"
```

---

## 4. CẤU HÌNH MySQL CHO SERVER 2 (script tự động)

Mở **PowerShell với quyền Administrator** (chuột phải → *Run as administrator*):

```powershell
cd C:\duong\dan\LTM_Lab8
Set-ExecutionPolicy -Scope Process Bypass -Force
.\scripts\setup_mysql_windows.ps1 -ServerId 2 -RootPass "070995"
```

Script làm 8 việc:

1. Sao lưu `my.ini`
2. Bật `server-id=2`, `log-bin`, `gtid_mode=ON`, `enforce_gtid_consistency=ON`, `log_replica_updates=ON`, `binlog_format=ROW`, `bind-address=0.0.0.0`
3. Restart service MySQL
4. Tạo database `shared_records` + bảng `records`, `record_locks` + user `appuser`, `replicator`
5. Mở firewall TCP 3306
6. In ra `server_id`, `gtid_mode` để xác nhận

> Nếu `my.ini` nằm ở chỗ khác, thêm `-MyIniPath "C:\ProgramData\MySQL\MySQL Server 8.4\my.ini"`.

**Trên Server 1 (máy bạn) chạy tương tự với `-ServerId 1`.**

---

## 5. BẬT ĐỒNG BỘ HAI CHIỀU

### Trên Server 2 (máy bạn bè, Windows)

```powershell
.\scripts\setup_replication_windows.ps1 -PeerHost 172.16.228.141 -RootPass "070995"
```

### Trên Server 1 (Ubuntu của bạn)

```bash
sudo bash scripts/setup_replication.sh 192.168.161.131
```

### Kỳ vọng

```
Replica_IO_Running: Yes
Replica_SQL_Running: Yes
Seconds_Behind_Source: 0
```

Nếu `Connecting`, xem `Last_IO_Error`:

```cmd
"C:\Program Files\MySQL\MySQL Server 8.4\bin\mysql.exe" -u root -p -e "SHOW REPLICA STATUS\G"
```

| Lỗi | Nguyên nhân thường gặp |
|---|---|
| `Can't connect to MySQL server` | IP sai / firewall / MySQL chưa chạy / NAT |
| `Access denied for user 'replicator'` | Chưa chạy `init_shared_records.sql`, hoặc sai mật khẩu `replica123` |
| `Authentication plugin 'caching_sha2_password' ... SSL` | Server kia chưa `REQUIRE SSL` cho `replicator` → chạy lại SQL init |
| `The slave is connecting using CHANGE REPLICATION SOURCE TO` | Bình thường, tự hết sau vài giây |

---

## 6. CHẠY ỨNG DỤNG JAVA SWING

Trong thư mục dự án:

```cmd
run.bat client2
```

hoặc nhấp đúp **`chay_client2.bat`**.

- `run.bat client2` → Client 2 (máy bạn bè)
- `run.bat server2` → app chạy ngay trên Server 2 để xem dữ liệu nhận được
- `run.bat` → dùng `config.properties` hiện có

Lần đầu sẽ biên dịch (khoảng 5–10 giây) rồi mở cửa sổ **"ĐỒNG BỘ CSDL 2 SERVER – 2 CLIENT"**.

> Nếu Windows SmartScreen cảnh báo khi chạy `.bat`: `More info` → `Run anyway`.

### Kiểm tra trên app

1. Tab **3. Đồng bộ & Kết nối** → `Kiểm tra kết nối`
   - Lock Manager (Server 1): **OK**
   - Server 2: **OK**
2. `Kiểm tra đồng bộ` → **ĐÃ ĐỒNG BỘ**
3. Tab **1** → `Tải lại danh sách` → thấy `SV001, SV002, SV003`.

---

## 7. FIREWALL & MẠNG

Windows firewall (đã làm tự động bởi script, nhưng kiểm tra lại):

```powershell
New-NetFirewallRule -DisplayName "MySQL 3306" -Direction Inbound -Protocol TCP -LocalPort 3306 -Action Allow -Profile Any
```

Kiểm tra thông mạng từ máy bạn bè:

```powershell
Test-NetConnection 172.16.228.141 -Port 3306
Test-NetConnection 172.26.40.121  -Port 3306
```

- `TcpTestSucceeded : True` → thông.
- `False` → xem lại mục 1 (NAT/Bridged) và firewall.

> Mạng `VKU_Student` thường bật **AP isolation** (client không nói chuyện được với nhau). Nếu ping Wi-Fi chéo thất bại, hãy dùng hotspot điện thoại hoặc phát Wi-Fi từ một máy.

---

## 8. KỊCH BẢN DEMO (2 máy)

| # | Thao tác | Kết quả mong đợi |
|---|---|---|
| 1 | Client 1 tạo `SV010` | Client 2 `Tải lại` → thấy `SV010` (đồng bộ) |
| 2 | Client 2 tạo lại `SV010` | Báo `Mã bản ghi 'SV010' đã tồn tại (vi phạm UNIQUE)` |
| 3 | Client 1 khóa `SV010` | Nhận `LOCK_TOKEN` |
| 4 | Client 2 xem danh sách | `SV010` hiện `ĐANG DÙNG bởi CLIENT-1` |
| 5 | Client 2 khóa `SV010` | `Bản ghi đang được sử dụng bởi CLIENT-1 ...` |
| 6 | Client 2 giải phóng bằng token sai | `Token không đúng hoặc bạn không phải chủ sở hữu khóa` |
| 7 | Client 1 giải phóng đúng token | `Đã giải phóng bản ghi` |
| 8 | Client 2 khóa lại `SV010` | Thành công, nhận token mới |
| 9 | Client 1 xóa bản ghi đang bị khóa | Bị chặn: `đang được sử dụng bởi ...` |
| 10 | Client 1 giải phóng rồi xóa | `Đã xóa bản ghi`, Client 2 tải lại không còn |

---

## 9. LỖI THƯỜNG GẶP

| Hiện tượng | Cách sửa |
|---|---|
| `'javac' is not recognized` | Cài JDK, mở cmd mới, kiểm tra `PATH` |
| `Could not find or load main class com.ltm.Main` | Chạy `run.bat` từ đúng thư mục dự án (nó tự biên dịch) |
| `Communications link failure` | MySQL chưa chạy / sai IP / firewall / NAT (mục 1) |
| `Access denied for user 'appuser'@'...'` | Chưa chạy `init_shared_records.sql`, hoặc `bind-address` chưa phải `0.0.0.0` |
| `Public Key Retrieval is not allowed` | App đã bật sẵn; nếu vẫn lỗi, kiểm tra URL JDBC có `allowPublicKeyRetrieval=true` |
| `ERROR 2003 (HY000)` | Không có MySQL ở cổng 3306 |
| `The MySQL service could not be started` sau khi sửa ini | Khôi phục `my.ini.bak_*` rồi sửa lại từng dòng |
| `Port 3306 already in use` | Đổi cổng trong installer **và** trong `my.ini` + config app |
| Chữ Việt trong cửa sổ cmd bị lỗi | `run.bat` đã `chcp 65001`; nếu vẫn lỗi, đổi font Consolas |
| `... cannot be loaded because running scripts is disabled` | `Set-ExecutionPolicy -Scope Process Bypass -Force` |
| App báo `FAIL` ở Lock Manager | `ping 172.16.228.141` + `Test-NetConnection ... -Port 3306` |
| Đồng bộ chậm vài giây | Bình thường; bấm `Tải lại danh sách` |

---

## 10. CHECKLIST

- [ ] `java -version` và `javac -version` chạy được
- [ ] MySQL service `MySQL84` đang Running
- [ ] `setup_mysql_windows.ps1 -ServerId 2` chạy xong, không lỗi
- [ ] `SHOW VARIABLES LIKE 'server_id'` = **2**
- [ ] `SHOW VARIABLES LIKE 'gtid_mode'` = **ON**
- [ ] `replicator` / `appuser` tồn tại
- [ ] Firewall 3306 mở
- [ ] `Test-NetConnection 172.16.228.141 -Port 3306` = True
- [ ] `Replica_IO_Running = Yes`, `Replica_SQL_Running = Yes`
- [ ] App mở được bằng `chay_client2.bat`
- [ ] Tab 3 báo **OK** cả 2 server
- [ ] Demo đồng bộ + khóa + xóa chạy đúng

---

Xem thêm: [`02_HUONG_DAN_TRIEN_KHAI.md`](02_HUONG_DAN_TRIEN_KHAI.md) · [`04_XU_LY_LOI.md`](04_XU_LY_LOI.md)
