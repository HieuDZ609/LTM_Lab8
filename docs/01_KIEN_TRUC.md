# 01 — KIẾN TRÚC HỆ THỐNG

## 1. Bài toán

Cần xây dựng hệ thống gồm:

- **2 Server** có cùng nội dung cơ sở dữ liệu.
- **2 Client** truy cập chéo: Client 1 vào Server 2, Client 2 vào Server 1.
- Dữ liệu tạo ở bất kỳ Server nào cũng phải xuất hiện ở Server còn lại.
- **Không được trùng bản ghi**.
- **Mỗi bản ghi chỉ một Client được sử dụng tại một thời điểm**; Client kia phải nhận lỗi.

## 2. Hai vấn đề tách biệt

Nhiều bạn gộp hai yêu cầu này thành một, dẫn đến thiết kế sai.

| Vấn đề | Bản chất | Công cụ giải quyết |
|---|---|---|
| **Chống trùng** | Ràng buộc toàn vẹn dữ liệu | `UNIQUE(record_code)` |
| **Khóa khi đang dùng** | Điều phối tạm thời giữa các Client | Bảng `record_locks` + `PRIMARY KEY` + lease |

Replication **không** giải quyết được vấn đề thứ hai. Replication chỉ trả lời câu hỏi "làm sao để dữ liệu giống nhau", không trả lời "ai được phép làm trước".

## 3. Kiến trúc chọn: Single-Writer + Distributed Lock

```
Client 1 ──► Server 2 ──┐
                        ├──► [LOCK MANAGER = Server 1] ──► records / record_locks
Client 2 ──► Server 1 ──┘
```

### Nguyên tắc

1. **Mọi thao tác ghi** (`INSERT`, `DELETE` khóa) đều thực thi tại **Server 1**.
2. **Server 2** nhận dữ liệu qua replication.
3. Cả hai Client đọc dữ liệu từ Lock Manager để thấy trạng thái mới nhất.

### Vì sao không dùng Multi-Master thuần?

Kịch bản nguy hiểm:

```
t=0.00s  Client 1 → Server 2: INSERT SV005   ✔ Server 2 chấp nhận
t=0.01s  Client 2 → Server 1: INSERT SV005   ✔ Server 1 chấp nhận
t=0.20s  Replication đồng bộ
         → Cả hai bên đều đã có SV005, xung đột chết replication
```

Trong khoảng 0.2 giây đó, **cả hai Client đều nghĩ mình thành công**. Yêu cầu "nếu trùng thì chắc chắn báo lỗi" bị vi phạm.

Khi mọi ghi đi về một node, thứ tự được tuần tự hoá: request thứ hai **luôn** nhận lỗi `1062`.

### Vì sao không dùng Group Replication?

Group Replication cần **đa số thành viên** (quorum). Với chỉ 2 node:

- 1 node mất mạng → mất quorum → cụm dừng phục vụ.
- Muốn chịu lỗi cần ít nhất 3 node.

Với phạm vi bài thực hành 2 server, Group Replication làm hệ thống **kém khả dụng hơn** mà không giải quyết được bài toán khóa.

## 4. Lược đồ dữ liệu

```sql
CREATE TABLE records (
  record_id   BIGINT AUTO_INCREMENT PRIMARY KEY,
  record_code VARCHAR(50)  NOT NULL,
  record_name VARCHAR(150) NOT NULL,
  created_at  TIMESTAMP    DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT uq_record_code UNIQUE (record_code)   -- chống trùng
) ENGINE=InnoDB;

CREATE TABLE record_locks (
  record_id   BIGINT      PRIMARY KEY,              -- mỗi bản ghi 1 khóa
  client_id   VARCHAR(50) NOT NULL,
  lock_token  CHAR(36)    NOT NULL,                 -- xác thực khi giải phóng
  locked_at   TIMESTAMP   DEFAULT CURRENT_TIMESTAMP,
  expires_at  TIMESTAMP   NOT NULL,                 -- lease, chống treo khóa
  CONSTRAINT fk_lock_record FOREIGN KEY (record_id)
      REFERENCES records(record_id) ON DELETE CASCADE
) ENGINE=InnoDB;
```

### Vai trò từng ràng buộc

| Ràng buộc | Chặn được gì |
|---|---|
| `UNIQUE(record_code)` | Hai bản ghi cùng mã |
| `PRIMARY KEY(record_id)` trong `record_locks` | Hai Client cùng giữ một bản ghi |
| `lock_token` | Client khác giải phóng hộ |
| `expires_at` | Khóa bị treo vĩnh viễn khi Client chết |
| `FOREIGN KEY ... ON DELETE CASCADE` | Khóa mồ côi khi xóa bản ghi |

## 5. Luồng cấp khóa

```
Client                Lock Manager (Server 1)              MySQL
  │                              │                          │
  ├─ Yêu cầu khóa SV001 ────────►│                          │
  │                              ├─ DELETE khóa hết hạn ───►│
  │                              ├─ INSERT record_locks ───►│
  │                              │                          ├─ PK trùng?
  │                              │◄── 1062 Duplicate ───────┤
  │◄─ "Đang được CLIENT-1 dùng" ─┤                          │
  │                              │                          │
  │  (nếu chưa ai giữ)           │                          │
  │◄─ SUCCESS + lock_token ──────┤                          │
```

Bước `INSERT` là **điểm tuần tự hoá duy nhất**. MySQL đảm bảo chỉ một trong hai `INSERT` đồng thời thành công.

## 6. Luồng tạo bản ghi

```
Client 1 → Server 2 (nhận request)
              │
              └─► Lock Manager (Server 1) ─ INSERT records
                                              │
                                              ├─ UNIQUE OK  → SUCCESS
                                              └─ trùng mã   → 1062 → "Mã đã tồn tại"
                                              │
                                        Replication
                                              ▼
                                          Server 2
```

## 7. Đồng bộ hai chiều

Cấu hình **GTID-based replication** cả hai hướng:

```
Server 1 ──binlog──► Server 2
Server 2 ──binlog──► Server 1
```

Thông số quan trọng:

| Tham số | Giá trị | Ý nghĩa |
|---|---|---|
| `gtid_mode` | ON | Định danh giao dịch toàn cục, tránh lặp vòng |
| `enforce_gtid_consistency` | ON | Bắt buộc để GTID hoạt động |
| `binlog_format` | ROW | Đồng bộ chính xác từng dòng |
| `log_replica_updates` | ON | **Bắt buộc** cho master-master |
| `SOURCE_AUTO_POSITION` | 1 | Tự bỏ qua giao dịch đã áp dụng → không lặp vòng |

`log_replica_updates = ON` là chi tiết dễ bỏ sót: nếu tắt, dữ liệu nhận từ Server 2 sẽ **không** được ghi lại vào binlog của Server 1, khiến Server 2 không bao giờ nhận được dữ liệu gốc từ Server 1 trong một số tình huống.

## 8. Giới hạn cần nêu trong báo cáo

| Giới hạn | Hệ quả | Hướng khắc phục |
|---|---|---|
| Server 1 là điểm chết duy nhất | Server 1 sập → không ghi/khóa được | Thêm node thứ ba + failover tự động |
| Độ trễ đồng bộ | Client đọc Server 2 có thể thấy dữ liệu chậm ~vài ms | Đọc từ Lock Manager khi cần chính xác tuyệt đối |
| Lease có thể hết hạn khi Client vẫn đang xử lý | Client mất quyền giữa chừng | Gia hạn lease định kỳ (`renew`) |
| Không có xác thực mạnh | Ai biết `appuser` đều ghi được | Tài khoản riêng + mật khẩu mạnh + TLS |

## 9. So sánh phương án

| Phương án | Chống trùng chắc chắn | Khóa phân tán | Độ phức tạp | Phù hợp bài lab |
|---|---|---|---|---|
| **Single-Writer + Lock (đã chọn)** | ✔ | ✔ | Thấp | ★★★★★ |
| MySQL Master-Master thuần | ✘ (có cửa sổ xung đột) | ✘ | Trung bình | ★★ |
| Group Replication 2 node | ✔ | Cần bảng khóa riêng | Cao, dễ mất quorum | ★★ |
| Galera 3 node | ✔ | Cần bảng khóa riêng | Cao | ★★★ |
| PostgreSQL + `pg_advisory_lock` | ✔ | ✔ | Trung bình | ★★★★ |
| Redis `SETNX` + MySQL | ✔ | ✔ | Trung bình | ★★★★ |
