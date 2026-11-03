# 05 — HƯỚNG DẪN TRÊN WINDOWS (MÁY BẠN BÈ)

Tài liệu cho **máy bạn bè (Windows)**: chạy **Client 2**, và cấu hình **Server 2** nằm trong VMware.

> Server 2 có thể là **Ubuntu** hoặc **Windows**. Chọn đúng nhánh ở mục 4:
> - **4A** — Server 2 chạy **Ubuntu** (giống Server 1 của bạn) → dùng script `.sh`
> - **4B** — Server 2 chạy **Windows** → dùng script `.ps1`

---

## 0. THÔNG TIN 4 MÁY

| Máy | Vai trò | IP | Ai chạy |
|---|---|---|---|
| **Client 1** | App Java Swing | `172.26.40.121` (Wi-Fi `VKU_Student` của bạn) | Bạn |
| **Server 1** | MySQL + **Lock Manager** | `172.16.228.141` (VMware trên máy bạn) | Bạn |
| **Client 2** | App Java Swing | `172.26.82.95` (Wi-Fi `VKU_Student` của bạn bè) | Bạn bè |
| **Server 2** | MySQL (nhận đồng bộ) | `192.168.161.131` (VMware trên máy bạn bè) | Bạn bè |

- `lockManager.host` **luôn = IP Server 1** trên cả 4 máy.
- IP Wi-Fi là DHCP, có thể đổi sau khi khởi động lại. Kiểm tra: `ipconfig` (Windows) / `hostname -I` (Linux).

---

## 1. ⚠️ ĐỌC TRƯỚC — VMware NAT và địa chỉ IP

`172.16.228.141` và `192.168.161.131` là IP **bên trong mạng NAT của VMware**, chỉ tồn tại trên chính máy chủ của nó:

```
Máy bạn (172.26.40.121)          Máy bạn bè (172.26.82.95)
┌──────────────────────┐         ┌──────────────────────┐
│  VMware NAT vmnet8   │    X    │  VMware NAT vmnet8   │
│  172.16.228.141      │         │  192.168.161.131     │
└──────────────────────┘         └──────────────────────┘
     Không kết nối chéo được nếu để NAT
```

Nghĩa là máy bạn bè **không thể** kết nối trực tiếp tới `172.16.228.141`, và ngược lại. Chọn **một** trong hai cách:

### Cách A (KHUYẾN NGHỊ) — chuyển card mạng VM sang Bridged

Làm trên **cả 2 máy**:

1. Tắt máy ảo.
2. VMware → `VM` → `Settings` → `Network Adapter`.
3. Chọn **Bridged** → tick `Replicate physical connection state` → OK.
4. Bật VM, lấy IP mới (`hostname -I` hoặc `ipconfig`).
5. Cập nhật IP mới vào các file `configs/*.properties` (xem bảng dưới).

| File | Sửa |
|---|---|
| `configs/server1.properties` | `server1.host` = IP mới Server 1 |
| `configs/client1.properties` | `server1.host`, `lockManager.host` = IP mới Server 1; `server2.host` = IP mới Server 2 |
| `configs/server2.properties` | `server2.host` = IP mới Server 2; `lockManager.host` = IP mới Server 1 |
| `configs/client2.properties` | `lockManager.host` = IP mới Server 1; `server2.host` = IP mới Server 2 |

> Bridged là cách ít lỗi nhất. Mạng `VKU_Student` có thể bật **AP isolation** (client không nói chuyện được với nhau) — nếu vậy hãy dùng hotspot điện thoại.

### Cách B — giữ NAT, dùng port forwarding

Trên **mỗi máy**: VMware → `Edit` → `Virtual Network Editor` → `Change Settings` (admin) → `VMnet8 (NAT)` → `NAT Settings` → `Add`:

| Host port | IP máy ảo | VM port | Máy |
|---|---|---|---|
| `3307` | `172.16.228.141` | `3306` | máy bạn |
| `3307` | `192.168.161.131` | `3306` | máy bạn bè |

Địa chỉ kết nối chéo = **IP Wi-Fi + cổng 3307**:

| Từ | Tới | Cấu hình |
|---|---|---|
| Client 2 | Server 1 | `lockManager.host=172.26.40.121`, `lockManager.port=3307` |
| Client 1 | Server 2 | `server2.host=172.26.82.95`, `server2.port=3307` |
| Server 1 | Server 2 | `-PeerHost 172.26.82.95 -PeerPort 3307` |
| Server 2 | Server 1 | `-PeerHost 172.26.40.121 -PeerPort 3307` |

Đồng thời mở firewall cổng **3307** trên **máy thật** (không phải trong VM).

---

## 2. CÀI JDK TRÊN MÁY WINDOWS (Client 2)

1. Tải **Eclipse Temurin JDK 21 (x64 MSI)**: <https://adoptium.net>
2. Cài, giữ tuỳ chọn `Set JAVA_HOME variable` và `Add to PATH`.
3. Mở **cmd mới**:

```cmd
java -version
javac -version
```

Phải hiện `javac 21.x`. Nếu `'javac' is not recognized`: cài lại và tick thêm PATH, hoặc thêm `C:\Program Files\Eclipse Adoptium\jdk-21...\bin` vào `Path`.

---

## 3. LẤY MÃ NGUỒN

```cmd
git clone https://github.com/HieuDZ609/LTM_Lab8.git
cd LTM_Lab8
```

Không có `git`? Tải ZIP trên trang GitHub → `Code` → `Download ZIP` → giải nén.

---

## 4. CẤU HÌNH MySQL TRÊN SERVER 2

### 4A. Server 2 chạy Ubuntu (khuyến nghị — giống máy bạn)

Mở terminal **trong máy ảo**:

```bash
# 1. Lấy mã nguồn
sudo apt update && sudo apt install -y git
git clone https://github.com/HieuDZ609/LTM_Lab8.git
cd LTM_Lab8

# 2. Cài MySQL + tạo DB/bảng/user + mở firewall (chọn 2 = Server 2)
sudo bash scripts/setup_mysql_ubuntu.sh 2

# 3. Bật đồng bộ về Server 1
sudo bash scripts/setup_replication.sh 172.16.228.141

# 4. Kiểm tra
mysql -e "SHOW REPLICA STATUS\G" | grep -E "Replica_IO_Running|Replica_SQL_Running"
```

Nếu dùng Cách B (port forwarding) thì bước 3 là:

```bash
sudo bash scripts/setup_replication.sh 172.26.40.121   # sửa script nếu cần cổng 3307
```

### 4B. Server 2 chạy Windows

Trong máy ảo Windows: cài **MySQL Server 8.4** bằng MySQL Installer:

1. Tải tại <https://dev.mysql.com/downloads/installer/>.
2. Chọn **Custom** → **MySQL Server 8.4** → Next → Execute.
3. `Type and Networking`: **Server Computer**, port **3306**, tick mở firewall.
4. `Authentication Method`: **Use Strong Password Encryption** (`caching_sha2_password`).
5. Đặt **root password** (nhớ kỹ).
6. `Windows Service`: tên `MySQL84`, tick chạy cùng Windows.

Sau đó mở **PowerShell (Run as administrator)** trong thư mục dự án:

```powershell
Set-ExecutionPolicy -Scope Process Bypass -Force
.\scripts\setup_mysql_windows.ps1 -ServerId 2 -RootPass "mat_khau_root"
```

Script tự: sao lưu `my.ini` → bật `server-id=2`, `log-bin`, `gtid_mode=ON`, `enforce_gtid_consistency=ON`, `log_replica_updates=ON`, `binlog_format=ROW`, `bind-address=0.0.0.0` → restart service → tạo `shared_records` + bảng + user `appuser`/`replicator` → mở firewall 3306.

> Nếu `my.ini` ở chỗ khác: thêm `-MyIniPath "C:\ProgramData\MySQL\MySQL Server 8.4\my.ini"`.

---

## 5. BẬT ĐỒNG BỘ HAI CHIỀU

### Trên Server 2

- **Ubuntu:** `sudo bash scripts/setup_replication.sh 172.16.228.141`
- **Windows:**

```powershell
.\scripts\setup_replication_windows.ps1 -PeerHost 172.16.228.141 -RootPass "mat_khau_root"
```

### Trên Server 1 (máy bạn)

- Nếu Server 2 là **Ubuntu**: `sudo bash scripts/setup_replication.sh 192.168.161.131`
- Nếu Server 2 là **Windows**: `sudo bash scripts/setup_replication.sh 192.168.161.131` (vẫn dùng script Linux, nó chỉ cần kết nối TCP tới MySQL của Windows)

### Kỳ vọng (trên cả 2 server)

```
Replica_IO_Running: Yes
Replica_SQL_Running: Yes
Seconds_Behind_Source: 0
```

Nếu `Connecting`, xem lỗi chi tiết:

```bash
mysql -e "SHOW REPLICA STATUS\G" | grep -E "Last_IO_Error|Last_SQL_Error"
```

| Lỗi | Nguyên nhân |
|---|---|
| `Can't connect to MySQL server` | IP sai / firewall / MySQL chưa chạy / NAT |
| `Access denied for user 'replicator'` | Chưa chạy `sql/init_shared_records.sql` hoặc sai mật khẩu |
| `Authentication plugin ... requires secure connection` | Chưa `REQUIRE SSL` cho `replicator` → chạy lại SQL init |
| `Connecting` vài giây đầu | Bình thường, tự chuyển `Yes` |

---

## 6. CHẠY ỨNG DỤNG (CLIENT 2)

Trong thư mục dự án trên máy Windows:

```cmd
run.bat client2
```

hoặc nhấp đúp **`chay_client2.bat`**.

- `run.bat client2` → Client 2
- `run.bat server2` → app chạy ngay trên Server 2 (nếu Server 2 là Windows)
- `run.bat` → dùng `config.properties` hiện có

Lần đầu biên dịch 5–10 giây rồi mở cửa sổ **"ĐỒNG BỘ CSDL 2 SERVER – 2 CLIENT"**.

> SmartScreen cảnh báo khi chạy `.bat`: `More info` → `Run anyway`.

### Kiểm tra

1. Tab **3. Đồng bộ & Kết nối** → `Kiểm tra kết nối` → cả 2 server **OK**.
2. `Kiểm tra đồng bộ` → **ĐÃ ĐỒNG BỘ**.
3. Tab **1** → `Tải lại danh sách` → thấy `SV001, SV002, SV003`.

---

## 7. FIREWALL & MẠNG

Mở cổng 3306 (script đã làm, kiểm tra lại nếu cần):

```powershell
New-NetFirewallRule -DisplayName "MySQL 3306" -Direction Inbound -Protocol TCP -LocalPort 3306 -Action Allow -Profile Any
```

Kiểm tra thông mạng:

```powershell
Test-NetConnection 172.16.228.141 -Port 3306
Test-NetConnection 172.26.40.121  -Port 3306
```

- `TcpTestSucceeded : True` → thông.
- `False` → xem lại mục 1 (NAT/Bridged) + firewall.

---

## 8. KỊCH BẢN DEMO

| # | Thao tác | Kết quả mong đợi |
|---|---|---|
| 1 | Client 1 tạo `SV010` | Client 2 `Tải lại` → thấy `SV010` (đồng bộ) |
| 2 | Client 2 tạo lại `SV010` | `Mã bản ghi 'SV010' đã tồn tại (vi phạm UNIQUE)` |
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
| `Could not find or load main class com.ltm.Main` | Chạy `run.bat` từ đúng thư mục dự án |
| `Communications link failure` | MySQL chưa chạy / sai IP / firewall / NAT |
| `Access denied for user 'appuser'@'...'` | Chưa chạy `init_shared_records.sql`, hoặc `bind-address` chưa `0.0.0.0` |
| `Public Key Retrieval is not allowed` | App đã bật sẵn; kiểm tra URL JDBC có `allowPublicKeyRetrieval=true` |
| `ERROR 2003 (HY000)` | Không có MySQL ở cổng 3306 |
| MySQL service không start sau khi sửa ini | Khôi phục `my.ini.bak_*` rồi sửa lại từng dòng |
| `Port 3306 already in use` | Đổi cổng trong installer **và** `my.ini` + config app |
| Chữ Việt trong cmd lỗi font | `run.bat` đã `chcp 65001`; đổi font cmd sang **Consolas** |
| `... running scripts is disabled` | `Set-ExecutionPolicy -Scope Process Bypass -Force` |
| App báo `FAIL` ở Lock Manager | `Test-NetConnection <IP_SERVER_1> -Port 3306` |
| Đồng bộ chậm vài giây | Bình thường; bấm `Tải lại danh sách` |

---

## 10. CHECKLIST

- [ ] `java -version` và `javac -version` chạy được
- [ ] Đã clone mã nguồn (hoặc giải nén ZIP)
- [ ] Server 2: MySQL đang chạy, `server_id=2`, `gtid_mode=ON`
- [ ] User `appuser` / `replicator` tồn tại trên Server 2
- [ ] Firewall 3306 mở trên Server 2
- [ ] `Test-NetConnection 172.16.228.141 -Port 3306` = True
- [ ] `Replica_IO_Running = Yes`, `Replica_SQL_Running = Yes` trên cả 2 server
- [ ] App mở được bằng `chay_client2.bat`
- [ ] Tab 3 báo **OK** cả 2 server
- [ ] Demo đồng bộ + chống trùng + khóa + xóa chạy đúng

---

Xem thêm: [`02_HUONG_DAN_TRIEN_KHAI.md`](02_HUONG_DAN_TRIEN_KHAI.md) · [`04_XU_LY_LOI.md`](04_XU_LY_LOI.md)
