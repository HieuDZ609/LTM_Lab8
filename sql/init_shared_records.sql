-- =========================================================
--  KHỞI TẠO DATABASE CHO MÔ HÌNH 2 SERVER – 2 CLIENT
--  Chạy trên CẢ Server 1 và Server 2 (nội dung giống nhau)
-- =========================================================

CREATE DATABASE IF NOT EXISTS shared_records
  CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE shared_records;

-- ---------- Bảng dữ liệu chính ----------
CREATE TABLE IF NOT EXISTS records (
  record_id   BIGINT AUTO_INCREMENT PRIMARY KEY,
  record_code VARCHAR(50)  NOT NULL,
  record_name VARCHAR(150) NOT NULL,
  created_at  TIMESTAMP    DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT uq_record_code UNIQUE (record_code)   -- chống trùng
) ENGINE=InnoDB;

-- ---------- Bảng khóa (lease) ----------
CREATE TABLE IF NOT EXISTS record_locks (
  record_id   BIGINT      PRIMARY KEY,             -- mỗi bản ghi 1 khóa
  client_id   VARCHAR(50) NOT NULL,
  lock_token  CHAR(36)    NOT NULL,                -- xác thực giải phóng
  locked_at   TIMESTAMP   DEFAULT CURRENT_TIMESTAMP,
  expires_at  TIMESTAMP   NOT NULL,                -- chống treo khóa
  CONSTRAINT fk_lock_record FOREIGN KEY (record_id)
      REFERENCES records(record_id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- ---------- Tài khoản ứng dụng ----------
CREATE USER IF NOT EXISTS 'appuser'@'%'
  IDENTIFIED WITH caching_sha2_password BY 'app123';
ALTER USER 'appuser'@'%'
  IDENTIFIED WITH caching_sha2_password BY 'app123';
GRANT SELECT, INSERT, UPDATE, DELETE ON shared_records.* TO 'appuser'@'%';

-- ---------- Tài khoản đồng bộ ----------
CREATE USER IF NOT EXISTS 'replicator'@'%'
  IDENTIFIED WITH caching_sha2_password BY 'replica123';
ALTER USER 'replicator'@'%'
  IDENTIFIED WITH caching_sha2_password BY 'replica123';
ALTER USER 'replicator'@'%' REQUIRE SSL;          -- cần cho replication
GRANT REPLICATION SLAVE ON *.* TO 'replicator'@'%';

FLUSH PRIVILEGES;

-- ---------- Dữ liệu mẫu ----------
INSERT IGNORE INTO records (record_code, record_name) VALUES
  ('SV001', 'Nguyen Van A'),
  ('SV002', 'Tran Van B'),
  ('SV003', 'Le Van C');

-- ---------- Kiểm tra ----------
SELECT 'Khởi tạo hoàn tất' AS ket_qua;
SHOW TABLES;
SELECT * FROM records;
