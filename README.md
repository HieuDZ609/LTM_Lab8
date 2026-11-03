# ĐỀ TÀI: ĐỒNG BỘ CƠ SỞ DỮ LIỆU GIỮA 2 SERVER
## VÀ KIỂM SOÁT TRUY CẬP BẢN GHI CỦA 2 CLIENT

Ứng dụng Java Swing + MySQL cho phép:

1. **Đồng bộ dữ liệu hai chiều** giữa Server 1 và Server 2.
2. **Chống trùng dữ liệu** — một mã bản ghi không thể tạo hai lần.
3. **Khóa bản ghi khi đang sử dụng** — mỗi bản ghi chỉ một Client dùng tại một thời điểm, Client còn lại nhận thông báo lỗi.

---

## 1. MÔ HÌNH

```
                       ┌──────────────────────────┐
                       │   LOCK MANAGER (Server 1) │
                       │   Quyết định cấp khóa      │
                       └────────────┬─────────────┘
                                    │
                    ┌───────────────┴───────────────┐
                    │                               │
             ┌──────▼──────┐                 ┌──────▼──────┐
             │  SERVER 1   │◄───đồng bộ─────►│  SERVER 2   │
             │   MySQL     │   hai chiều     │   MySQL     │
             └──────▲──────┘                 └──────▲──────┘
                    │                               │
             ┌──────┴──────┐                 ┌──────┴──────┐
             │  CLIENT 2   │                 │  CLIENT 1   │
             │ (VM bạn bè) │                 │ (VM của bạn)│
             └─────────────┘                 └─────────────┘
```

| Máy | Vai trò | Nhiệm vụ |
|---|---|---|
| **Server 1** (máy tính của bạn) | MySQL + Lock Manager | Nơi **duy nhất** cấp khóa và xử lý ghi |
| **Server 2** (máy bạn bè) | MySQL replica | Nhận đồng bộ, phục vụ đọc |
| **Client 1** (VMware của bạn) | Client | Kết nối Server 2, thao tác đi về Server 1 |
| **Client 2** (VMware bạn bè) | Client | Kết nối Server 1 |

---

## 2. CẤU TRÚC THƯ MỤC

```
DeTai_SyncDB_2Server_2Client/
├── config.properties              ← CẤU HÌNH CHÍNH (sửa IP ở đây)
├── configs/                       ← Mẫu cấu hình cho từng máy
│   ├── server1.properties
│   ├── server2.properties
│   ├── client1.properties
│   └── client2.properties
├── lib/
│   └── mysql-connector-j-8.4.0.jar
├── sql/
│   └── init_shared_records.sql
├── scripts/
│   ├── setup_mysql_ubuntu.sh      ← Cài MySQL + tạo DB (Ubuntu)
│   ├── setup_replication.sh       ← Bật đồng bộ 2 chiều
│   └── check_status.sh            ← Kiểm tra nhanh
├── src/com/ltm/
│   ├── Main.java
│   ├── db/DBConnection.java
│   ├── model/Record.java
│   ├── model/RecordLock.java
│   ├── service/RecordService.java
│   └── ui/MainFrame.java          ← Giao diện Java Swing
├── docs/
│   ├── 01_KIEN_TRUC.md
│   ├── 02_HUONG_DAN_TRIEN_KHAI.md
│   ├── 03_KICH_BAN_KIEM_THU.md
│   └── 04_XU_LY_LOI.md
├── run.sh                         ← Chạy trên Linux
├── run.bat                        ← Chạy trên Windows
└── README.md
```

---

## 3. CHẠY NHANH (3 BƯỚC)

### Bước 1 — Cài MySQL trên Server 1 và Server 2

Trên **mỗi** máy Ubuntu:

```bash
sudo bash scripts/setup_mysql_ubuntu.sh 1     # Server 1
sudo bash scripts/setup_mysql_ubuntu.sh 2     # Server 2
```

### Bước 2 — Bật đồng bộ hai chiều

Trên **Server 1**:

```bash
sudo bash scripts/setup_replication.sh <IP_SERVER_2>
```

Trên **Server 2**:

```bash
sudo bash scripts/setup_replication.sh <IP_SERVER_1>
```

Kiểm tra: `Replica_IO_Running: Yes` và `Replica_SQL_Running: Yes`.

### Bước 3 — Sửa IP và chạy app

Mở `config.properties`, sửa:

- `lockManager.host` = **IP Server 1** (bắt buộc, giống nhau trên mọi máy)
- `server2.host` = IP Server 2
- `CLIENT_ID` = `CLIENT-1` hoặc `CLIENT-2` (khác nhau giữa 2 client)
- `ROLE` = `SERVER1` / `SERVER2` / `CLIENT1` / `CLIENT2`

Lấy IP bằng lệnh:

```bash
hostname -I
```

Chạy:

```bash
./run.sh          # Linux
run.bat           # Windows
```

---

## 4. GIAO DIỆN

| Tab | Chức năng |
|---|---|
| **1. Danh sách bản ghi** | Xem toàn bộ bản ghi, trạng thái khóa, tạo bản ghi mới |
| **2. Khóa / Giải phóng** | Cấp khóa (trả về `LOCK_TOKEN`), giải phóng khóa |
| **3. Đồng bộ & Kết nối** | Kiểm tra kết nối 2 server, kiểm tra đồng bộ, xem replication |
| **4. Nhật ký** | Ghi lại mọi thao tác và lỗi |

### Cách dùng cơ bản

**Tạo bản ghi**: Tab 1 → `Tạo bản ghi mới` → nhập mã + tên.
→ Nếu mã đã tồn tại: báo `Mã bản ghi ... đã tồn tại (vi phạm UNIQUE)`.

**Khóa bản ghi**: Tab 2 (trái) → chọn bản ghi đang rảnh → nhập Client ID → `KHÓA BẢN GHI`.
→ Thành công: nhận `LOCK_TOKEN`, token tự điền sang khung giải phóng.
→ Nếu Client khác đang giữ: báo `Bản ghi đang được sử dụng bởi CLIENT-X`.

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
| Java | JDK 17 trở lên |
| MySQL | 8.0 / 8.4 LTS |
| OS Server | Ubuntu 22.04+ / Debian 12+ / Windows |
| Mạng | Các máy ping được nhau, mở cổng 3306 |

---

## 7. TÀI KHOẢN MẶC ĐỊNH

| Loại | User | Password | Quyền |
|---|---|---|---|
| Ứng dụng | `appuser` | `app123` | SELECT/INSERT/UPDATE/DELETE trên `shared_records` |
| Đồng bộ | `replicator` | `replica123` | REPLICATION SLAVE |

> Đổi mật khẩu trong `scripts/setup_mysql_ubuntu.sh` và `config.properties` nếu triển khai thật.

---

## 8. TÀI LIỆU CHI TIẾT

- [`docs/01_KIEN_TRUC.md`](docs/01_KIEN_TRUC.md) — Kiến trúc, lý do thiết kế, so sánh phương án
- [`docs/02_HUONG_DAN_TRIEN_KHAI.md`](docs/02_HUONG_DAN_TRIEN_KHAI.md) — Hướng dẫn từng bước cho 4 máy
- [`docs/03_KICH_BAN_KIEM_THU.md`](docs/03_KICH_BAN_KIEM_THU.md) — 10 test case + kết quả mong đợi
- [`docs/04_XU_LY_LOI.md`](docs/04_XU_LY_LOI.md) — Lỗi thường gặp và cách sửa
