# 03 — KỊCH BẢN KIỂM THỬ

Bảng kiểm thử dùng để nghiệm thu và đưa vào báo cáo.

## A. Kiểm thử chức năng

| # | Kịch bản | Thao tác | Kết quả mong đợi | Kết quả thực tế |
|---|---|---|---|---|
| 1 | Tạo bản ghi thành công | Client 1 → Tạo `SV010` | Thông báo thành công, bản ghi xuất hiện trong bảng | ☐ Đạt ☐ Không |
| 2 | Đồng bộ sang Server 2 | Sau bước 1, mở app trên Client 2 → Tải lại | Thấy `SV010` | ☐ Đạt ☐ Không |
| 3 | Đồng bộ ngược chiều | Client 2 → Tạo `SV011` → Client 1 tải lại | Client 1 thấy `SV011` | ☐ Đạt ☐ Không |
| 4 | Chống trùng | Client 2 tạo lại `SV010` | `Mã bản ghi 'SV010' đã tồn tại (vi phạm UNIQUE)` | ☐ Đạt ☐ Không |
| 5 | Khóa bản ghi | Client 1 khóa `SV010` | Nhận `LOCK_TOKEN`, trạng thái `ĐANG DÙNG bởi CLIENT-1` | ☐ Đạt ☐ Không |
| 6 | Khóa trùng bản ghi | Client 2 khóa `SV010` | `Bản ghi đang được sử dụng bởi CLIENT-1` | ☐ Đạt ☐ Không |
| 7 | Giải phóng đúng token | Client 1 giải phóng với token đúng | Thành công, trạng thái về `Rảnh` | ☐ Đạt ☐ Không |
| 8 | Giải phóng sai token | Client 2 nhập token bất kỳ | `Token không đúng hoặc bạn không phải chủ sở hữu khóa` | ☐ Đạt ☐ Không |
| 9 | Khóa sau khi giải phóng | Client 2 khóa `SV010` | Thành công, nhận token mới | ☐ Đạt ☐ Không |
| 10 | Kiểm tra đồng bộ | Tab 3 → `Kiểm tra đồng bộ` | `ĐÃ ĐỒNG BỘ (S1: N = S2: N)` | ☐ Đạt ☐ Không |

## B. Kiểm thử đồng thời (quan trọng nhất)

| # | Kịch bản | Cách thực hiện | Kết quả mong đợi |
|---|---|---|---|
| 11 | Hai client khóa cùng lúc | Bấm `KHÓA` trên 2 app gần như đồng thời (cùng 1 bản ghi) | **Đúng 1 bên thành công**, bên kia nhận `đang được sử dụng` |
| 12 | Hai client tạo cùng mã | Bấm `Tạo` với cùng `record_code` trên 2 app | **Đúng 1 bên thành công**, bên kia nhận lỗi UNIQUE |
| 13 | Khóa rồi tạo mã khác | Client 1 giữ `SV040`, Client 2 tạo `SV041` | Cả hai thành công (khóa không chặn tạo bản ghi khác) |
| 14 | Nhiều bản ghi cùng lúc | Client 1 khóa `SV050`, Client 2 khóa `SV051` | Cả hai thành công (khóa độc lập theo bản ghi) |

### Cách chạy test đồng thời bằng script

```bash
# Khóa cùng bản ghi từ 2 "client" gần như đồng thời
mysql shared_records -e "INSERT INTO records (record_code,record_name) VALUES ('RACE01','Race test');"
RID=$(mysql -N shared_records -e "SELECT record_id FROM records WHERE record_code='RACE01';")

( mysql shared_records -e "INSERT INTO record_locks (record_id,client_id,lock_token,expires_at)
  VALUES ($RID,'CLIENT-1',UUID(),DATE_ADD(NOW(),INTERVAL 2 MINUTE));" 2>&1 | sed 's/^/[C1] /' ) &
( mysql shared_records -e "INSERT INTO record_locks (record_id,client_id,lock_token,expires_at)
  VALUES ($RID,'CLIENT-2',UUID(),DATE_ADD(NOW(),INTERVAL 2 MINUTE));" 2>&1 | sed 's/^/[C2] /' ) &
wait

mysql shared_records -e "SELECT record_id,client_id FROM record_locks WHERE record_id=$RID;"
# Kỳ vọng: đúng 1 dòng, 1 bên báo Duplicate entry '...' for key 'record_locks.PRIMARY'
```

## C. Kiểm thử độ bền (lease)

| # | Kịch bản | Cách thực hiện | Kết quả mong đợi |
|---|---|---|---|
| 15 | Khóa hết hạn tự giải phóng | Đặt `lease.minutes=1`, khóa rồi đợi 70s | Bản ghi về `Rảnh`, client khác khóa được |
| 16 | Client chết đột ngột | Khóa xong tắt app không giải phóng | Sau khi hết lease, client khác khóa được |
| 17 | Xóa bản ghi đang khóa | `DELETE FROM records WHERE record_id=X` | Khóa tự xóa theo (`ON DELETE CASCADE`), không lỗi FK |

## D. Kiểm thử sự cố

| # | Kịch bản | Cách thực hiện | Kết quả mong đợi |
|---|---|---|---|
| 18 | Server 2 sập | `systemctl stop mysql` trên Server 2 | Client vẫn tạo/khóa được qua Server 1; tab 3 báo Server 2 = FAIL |
| 19 | Server 2 hoạt động lại | `systemctl start mysql` trên Server 2 | Replication tự nối lại, dữ liệu bù đầy đủ |
| 20 | Server 1 sập | `systemctl stop mysql` trên Server 1 | App báo lỗi kết nối, **không** cho ghi (an toàn, không sai dữ liệu) |
| 21 | Đổi IP Server 2 | Sửa IP rồi chạy lại app | App báo FAIL nhanh (timeout 3s), không treo |

## E. Kết quả kiểm thử tự động (đã chạy)

Chạy `SmokeTest` trực tiếp trên Server 1:

```
== 1. Doc danh sach ==
   So ban ghi: 4
   1 | SV001 | Rảnh
   2 | SV002 | Rảnh
   3 | SV003 | Rảnh
   4 | SV999 | Rảnh
== 2. Tao ban ghi trung (phai loi) ==
   ERR_DUPLICATE:Mã bản ghi 'SV001' đã tồn tại (vi phạm UNIQUE)
== 3. Client 1 khoa ==
   SUCCESS:0d995ed2-eb89-4c12-9d60-b0ab1a466522
== 4. Client 2 khoa cung ban ghi (phai loi) ==
   ERR_IN_USE:Bản ghi đang được sử dụng bởi CLIENT-1 (hết hạn: 2026-10-27 21:36:25.0)
== 5. Giai phong sai token (phai loi) ==
   ERR:Token không đúng hoặc bạn không phải chủ sở hữu khóa
== 6. Giai phong dung token ==
   SUCCESS:Đã giải phóng bản ghi
== 7. Client 2 khoa lai (phai thanh cong) ==
   SUCCESS:76c749b7-247a-4d3a-8a07-3ab7a5c246f9
== 8. Kiem tra ket noi + dong bo ==
   LockManager=true
   Server1=true
   Server2=true
   Count S1=4 S2=4

KET QUA: PASS=6 FAIL=0
```

→ **6/6 test logic đạt**, đồng bộ S1 = S2 = 4 bản ghi.

## F. Bảng tổng hợp để báo cáo

| Nhóm chức năng | Số test | Đạt | Ghi chú |
|---|---|---|---|
| Tạo & đồng bộ | 3 | | |
| Chống trùng | 2 | | |
| Khóa / giải phóng | 5 | | |
| Đồng thời | 4 | | |
| Lease | 3 | | |
| Sự cố | 4 | | |
| **Tổng** | **21** | | |
