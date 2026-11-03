# ĐỀ TÀI: ĐỒNG BỘ CƠ SỞ DỮ LIỆU GIỮA 2 SERVER
## VÀ KIỂM SOÁT TRUY CẬP BẢN GHI CỦA 2 CLIENT

Ứng dụng **Java Swing + MySQL** cho phép:

1. **Đồng bộ dữ liệu hai chiều** giữa Server 1 và Server 2 (GTID replication).
2. **Chống trùng dữ liệu** — một mã bản ghi không thể tạo hai lần.
3. **Khóa bản ghi khi đang sử dụng** — mỗi bản ghi chỉ một Client dùng tại một thời điểm.
4. **Tạo và xóa bản ghi** — thao tác đi qua Lock Manager rồi đồng bộ sang server còn lại.
5. **Chạy được trên cả server** — app Java Swing cũng hoạt động ngay trên Server 1 / Server 2.

---

## 1. MÔ HÌNH & ĐỊA CHỈ IP

```
                          ┌───────────────────────────┐
                          │  SERVER 1 (172.16.228.141) │
                          │  MySQL + LOCK MANAGER      │
                          └─────────────┬─────────────┘
                                        │  đồng bộ 2 chiều (GTID)
                          ┌─────────────▼─────────────┐
                          │  SERVER 2 (192.168.161.131)│
                          │  MySQL (replica)           │
                          └───────────────────────────┘

   CLIENT 1 (172.26.40.121)  ──┐        ┌── CLIENT 2 (172.26.82.95)
   máy của bạn                  └──► Server 1 ◄──┘   máy bạn bè
                                 (mọi thao tác ghi/khóa)
```

| Máy | Vai trò | IP | Ghi chú |
|---|---|---|---|
| **Client 1** | App Java Swing | `172.26.40.121` | Máy bạn, Wi-Fi `VKU_Student` |
| **Server 1** | MySQL + **Lock Manager** | `172.16.228.141` | VMware trên máy bạn |
| **Client 2** | App Java Swing | `172.26.82.95` | Máy bạn bè (Windows), Wi-Fi `VKU_Student` |
| **Server 2** | MySQL (replica) | `192.168.161.131` | VMware trên máy bạn bè (Windows) |

> `lockManager.host` **luôn = `172.16.228.141`** trên cả 4 máy.
>
> ⚠️ Nếu 2 máy không ping/không kết nối được cổng 3306 của nhau: IP `172.16.x.x` và `192.168.x.x` là mạng **NAT nội bộ VMware**. Chuyển card mạng VM sang **Bridged** (hoặc dùng port forwarding 3307) — xem **mục 1** của [docs/05_HUONG_DAN_WINDOWS.md](docs/05_HUONG_DAN_WINDOWS.md).

---

## 2. CẤU TRÚC THƯ MỤC

```
DeTai_SyncDB_2Server_2Client/
├── config.properties              ← CẤU HÌNH ĐANG DÙNG
├── configs/                       ← Mẫu cấu hình cho từng máy
│   ├── client1.properties         ← máy bạn
│   ├── client2.properties         ← máy bạn bè (Windows)
│   ├── server1.properties         ← chạy app trên Server 1
│   ├── server2.properties         ← chạy app trên Server 2
│   ├── desktop_server1_client1.properties
│   ├── vm_server2.properties
│   └── vm_client2.properties
├── lib/mysql-connector-j-8.4.0.jar
├── sql/init_shared_records.sql    ← DB + bảng + user + dữ liệu mẫu
├── scripts/
│   ├── setup_mysql_ubuntu.sh      ← cài MySQL trên Ubuntu
│   ├── setup_replication.sh       ← bật đồng bộ trên Ubuntu
│   ├── check_status.sh            ← kiểm tra nhanh
│   ├── setup_mysql_windows.ps1    ← cài/cấu hình MySQL trên Windows
│   ├── setup_replication_windows.ps1 ← bật đồng bộ trên Windows
│   └── mysql_common.ps1           ← hàm dùng chung cho 2 script Windows
├── src/com/ltm/
│   ├── Main.java
│   ├── db/DBConnection.java
│   ├── model/Record.java
│   ├── model/RecordLock.java
│   ├── service/RecordService.java
│   └── ui/MainFrame.java          ← giao diện Java Swing
├── docs/
│   ├── 01_KIEN_TRUC.md
│   ├── 02_HUONG_DAN_TRIEN_KHAI.md
│   ├── 03_KICH_BAN_KIEM_THU.md
│   ├── 04_XU_LY_LOI.md
│   └── 05_HUONG_DAN_WINDOWS.md    ← dành cho máy Windows
├── run.sh / run.sh client1        ← chạy trên Linux
├── run.bat / run.bat client2      ← chạy trên Windows
├── chay_client2.bat               ← nhấp đúp cho máy bạn bè
└── chay_server2.bat               ← nhấp đúp cho Server 2
```

---

## 3. CHẠY NHANH

### 3.1. Trên Ubuntu (Server 1 / máy bạn)

```bash
# Cài MySQL + tạo DB (chọn 1 = Server 1)
sudo bash scripts/setup_mysql_ubuntu.sh 1

# Bật đồng bộ tới Server 2
sudo bash scripts/setup_replication.sh 192.168.161.131

# Chọn cấu hình + chạy app
cp configs/client1.properties config.properties
./run.sh
```

### 3.2. Trên Windows (Server 2 / máy bạn bè)

Chạy **PowerShell với quyền Administrator**:

```powershell
# 1. Cấu hình MySQL: GTID, binlog, bind 0.0.0.0, tạo DB/bảng/user, mở firewall
.\scripts\setup_mysql_windows.ps1 -ServerId 2 -RootPass "mat_khau_root"

# 2. Bật đồng bộ về Server 1
.\scripts\setup_replication_windows.ps1 -PeerHost 172.16.228.141 -RootPass "mat_khau_root"

# 3. Chạy app (tự copy config + biên dịch)
run.bat client2
```

Hoặc nhấp đúp **`chay_client2.bat`**. Chi tiết: [`docs/05_HUONG_DAN_WINDOWS.md`](docs/05_HUONG_DAN_WINDOWS.md).

### 3.3. Chạy app trên server

| Máy | Lệnh |
|---|---|
| Server 1 | `cp configs/server1.properties config.properties && ./run.sh` |
| Server 2 | `run.bat server2` |

### 3.4. Kiểm tra

```bash
mysql -e "SHOW REPLICA STATUS\G" | grep -E "IO_Running|SQL_Running"
# → Replica_IO_Running: Yes / Replica_SQL_Running: Yes
```

---

## 4. GIAO DIỆN

| Tab | Chức năng |
|---|---|
| **1. Danh sách bản ghi** | Xem bản ghi, trạng thái khóa, **tạo mới**, **xóa bản ghi đã chọn** |
| **2. Khóa / Giải phóng** | Cấp khóa (trả `LOCK_TOKEN`), giải phóng khóa |
| **3. Đồng bộ & Kết nối** | Kiểm tra 2 server, kiểm tra đồng bộ, xem replication |
| **4. Nhật ký** | Ghi lại mọi thao tác và lỗi |

### Cách dùng cơ bản

**Tạo bản ghi**: Tab 1 → `Tạo bản ghi mới` → nhập mã + tên.
→ Nếu mã đã tồn tại: `Mã bản ghi ... đã tồn tại (vi phạm UNIQUE)`.

**Xóa bản ghi**: Tab 1 → chọn dòng → `Xóa bản ghi đã chọn` → xác nhận.
→ Nếu bản ghi đang bị khóa: bị chặn, phải `GIẢI PHÓNG` trước.
→ Xóa thành công sẽ đồng bộ sang server còn lại.

**Khóa bản ghi**: Tab 2 (trái) → chọn bản ghi đang rảnh → nhập Client ID → `KHÓA BẢN GHI`.
→ Thành công: nhận `LOCK_TOKEN`, token tự điền sang khung giải phóng.
→ Nếu Client khác đang giữ: `Bản ghi đang được sử dụng bởi CLIENT-X`.

**Giải phóng**: Tab 2 (phải) → chọn bản ghi → nhập Client ID + token → `GIẢI PHÓNG BẢN GHI`.
→ Sai token: báo lỗi, khóa vẫn giữ nguyên.

---

## 5. NGUYÊN TẮC HOẠT ĐỘNG

### Chống trùng
Cột `records.record_code` có `UNIQUE`. MySQL tự từ chối bản ghi trùng ở tầng database, không phụ thuộc ứng dụng.

### Khóa bản ghi
Bảng `record_locks` có `PRIMARY KEY(record_id)` → mỗi bản ghi chỉ tồn tại **tối đa một** dòng khóa. Khi Client thứ hai cố `INSERT`, MySQL trả lỗi `1062` → app hiển thị "đang được sử dụng".

### Vì sao mọi thao tác ghi đi qua Server 1?
Nếu mỗi server tự cấp khóa, hai client có thể cùng được chấp nhận trong vài mili-giây (dữ liệu chưa kịp đồng bộ). Đưa toàn bộ ghi/khóa về **một nơi duy nhất** loại bỏ hoàn toàn khoảng thời gian nguy hiểm đó.

### Vì sao cần lease (`expires_at`)?
Nếu Client tắt đột ngột, khóa sẽ bị treo vĩnh viễn. `expires_at` cho phép khóa tự hết hiệu lực sau `lease.minutes` phút, và lần cấp khóa kế tiếp sẽ dọn khóa hết hạn.

Xem chi tiết: [`docs/01_KIEN_TRUC.md`](docs/01_KIEN_TRUC.md)

---

## 6. YÊU CẦU HỆ THỐNG

| Thành phần | Phiên bản |
|---|---|
| Java | JDK 17 trở lên (khuyến nghị 21) |
| MySQL | 8.0 / 8.4 LTS |
| OS Server | Ubuntu 22.04+ / Debian 12+ / Windows 10-11 |
| Mạng | Các máy ping được nhau, mở cổng 3306 |

---

## 7. TÀI KHOẢN MẶC ĐỊNH

| Loại | User | Password | Quyền |
|---|---|---|---|
| Ứng dụng | `appuser` | `app123` | SELECT/INSERT/UPDATE/DELETE trên `shared_records` |
| Đồng bộ | `replicator` | `replica123` | REPLICATION SLAVE (yêu cầu SSL) |

> Đổi mật khẩu trong `scripts/setup_mysql_*` và `config.properties` nếu triển khai thật.

---

## 8. TÀI LIỆU CHI TIẾT

- [`docs/01_KIEN_TRUC.md`](docs/01_KIEN_TRUC.md) — Kiến trúc, lý do thiết kế, so sánh phương án
- [`docs/02_HUONG_DAN_TRIEN_KHAI.md`](docs/02_HUONG_DAN_TRIEN_KHAI.md) — Triển khai từng bước cho 4 máy
- [`docs/03_KICH_BAN_KIEM_THU.md`](docs/03_KICH_BAN_KIEM_THU.md) — Kịch bản kiểm thử + kết quả mong đợi
- [`docs/04_XU_LY_LOI.md`](docs/04_XU_LY_LOI.md) — Lỗi thường gặp và cách sửa
- [`docs/05_HUONG_DAN_WINDOWS.md`](docs/05_HUONG_DAN_WINDOWS.md) — **Hướng dẫn Windows cho máy bạn bè**
- [`HUONG_DAN_NHANH.txt`](HUONG_DAN_NHANH.txt) — Bản tóm tắt 1 trang
