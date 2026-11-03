package com.ltm.service;

import com.ltm.db.DBConnection;
import com.ltm.model.Record;

import java.sql.*;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

/**
 * Toàn bộ thao tác GHI (tạo bản ghi, khóa, giải phóng) đều đi qua
 * Lock Manager = Server 1. Nhờ vậy hai Client không bao giờ cùng
 * được cấp khóa cho một bản ghi.
 */
public class RecordService {

    /** Đọc danh sách bản ghi + trạng thái khóa hiện tại. */
    public List<Record> getAllRecords() throws SQLException {
        List<Record> list = new ArrayList<>();
        String sql = "SELECT record_id, record_code, record_name, created_at FROM records ORDER BY record_id ASC";
        try (Connection conn = DBConnection.getLockManager();
             Statement st = conn.createStatement();
             ResultSet rs = st.executeQuery(sql)) {
            while (rs.next()) {
                list.add(new Record(
                        rs.getLong("record_id"),
                        rs.getString("record_code"),
                        rs.getString("record_name"),
                        rs.getTimestamp("created_at")));
            }
        }

        String lockSql = "SELECT record_id, client_id FROM record_locks WHERE expires_at > NOW()";
        try (Connection conn = DBConnection.getLockManager();
             Statement st = conn.createStatement();
             ResultSet rs = st.executeQuery(lockSql)) {
            while (rs.next()) {
                long rid = rs.getLong("record_id");
                String cid = rs.getString("client_id");
                for (Record r : list) {
                    if (r.getRecordId() == rid) {
                        r.setStatus("ĐANG DÙNG bởi " + cid);
                        break;
                    }
                }
            }
        }
        return list;
    }

    /** Tạo bản ghi mới. UNIQUE(record_code) chặn trùng. */
    public String createRecord(String code, String name) {
        if (code == null || code.trim().isEmpty() || name == null || name.trim().isEmpty()) {
            return "ERR:Vui lòng nhập đầy đủ mã và tên bản ghi";
        }
        String sql = "INSERT INTO records (record_code, record_name) VALUES (?, ?)";
        try (Connection conn = DBConnection.getLockManager();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setString(1, code.trim());
            ps.setString(2, name.trim());
            ps.executeUpdate();
            return "SUCCESS:Tạo bản ghi " + code.trim() + " thành công";
        } catch (SQLException e) {
            if (e.getErrorCode() == 1062) {
                return "ERR_DUPLICATE:Mã bản ghi '" + code.trim() + "' đã tồn tại (vi phạm UNIQUE)";
            }
            return "ERR:" + e.getMessage();
        }
    }

    /** Cấp lease (khóa) cho một Client. PRIMARY KEY(record_id) chặn 2 client cùng giữ. */
    public String lockRecord(long recordId, String clientId) {
        if (clientId == null || clientId.trim().isEmpty()) {
            return "ERR:Chưa nhập Client ID";
        }
        // Dọn lease hết hạn trước khi cấp mới
        try (Connection conn = DBConnection.getLockManager();
             Statement st = conn.createStatement()) {
            st.executeUpdate("DELETE FROM record_locks WHERE expires_at < NOW()");
        } catch (SQLException ignored) { }

        String token = UUID.randomUUID().toString();
        int minutes = DBConnection.getLeaseMinutes();
        String sql = "INSERT INTO record_locks (record_id, client_id, lock_token, expires_at) "
                   + "VALUES (?, ?, ?, DATE_ADD(NOW(), INTERVAL ? MINUTE))";
        try (Connection conn = DBConnection.getLockManager();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setLong(1, recordId);
            ps.setString(2, clientId.trim());
            ps.setString(3, token);
            ps.setInt(4, minutes);
            ps.executeUpdate();
            return "SUCCESS:" + token;
        } catch (SQLException e) {
            if (e.getErrorCode() == 1062) {
                return "ERR_IN_USE:Bản ghi đang được sử dụng bởi " + getHolder(recordId);
            }
            return "ERR:" + e.getMessage();
        }
    }

    /** Giải phóng khóa, bắt buộc đúng client_id + lock_token. */
    public String unlockRecord(long recordId, String clientId, String token) {
        if (token == null || token.trim().isEmpty()) {
            return "ERR:Chưa nhập LOCK_TOKEN";
        }
        String sql = "DELETE FROM record_locks WHERE record_id = ? AND client_id = ? AND lock_token = ?";
        try (Connection conn = DBConnection.getLockManager();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setLong(1, recordId);
            ps.setString(2, clientId == null ? "" : clientId.trim());
            ps.setString(3, token.trim());
            int rows = ps.executeUpdate();
            if (rows == 1) return "SUCCESS:Đã giải phóng bản ghi";
            return "ERR:Token không đúng hoặc bạn không phải chủ sở hữu khóa";
        } catch (SQLException e) {
            return "ERR:" + e.getMessage();
        }
    }

    /** Xóa bản ghi. Không cho xóa nếu đang bị khóa. */
    public String deleteRecord(long recordId) {
        // Kiểm tra khóa còn hiệu lực
        String lockSql = "SELECT client_id FROM record_locks WHERE record_id = ? AND expires_at > NOW()";
        try (Connection conn = DBConnection.getLockManager();
             PreparedStatement ps = conn.prepareStatement(lockSql)) {
            ps.setLong(1, recordId);
            try (ResultSet rs = ps.executeQuery()) {
                if (rs.next()) {
                    return "ERR_LOCKED:Bản ghi đang được sử dụng bởi " + rs.getString("client_id") + ", không thể xóa";
                }
            }
        } catch (SQLException e) {
            return "ERR:" + e.getMessage();
        }

        // Xóa khóa hết hạn (nếu có) rồi xóa bản ghi
        try (Connection conn = DBConnection.getLockManager();
             PreparedStatement ps = conn.prepareStatement("DELETE FROM record_locks WHERE record_id = ?")) {
            ps.setLong(1, recordId);
            ps.executeUpdate();
        } catch (SQLException ignored) { }

        String sql = "DELETE FROM records WHERE record_id = ?";
        try (Connection conn = DBConnection.getLockManager();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setLong(1, recordId);
            int rows = ps.executeUpdate();
            if (rows == 1) return "SUCCESS:Đã xóa bản ghi";
            return "ERR:Không tìm thấy bản ghi";
        } catch (SQLException e) {
            return "ERR:" + e.getMessage();
        }
    }

    /** Xem ai đang giữ khóa (kể cả đã hết hạn). */
    public String getHolder(long recordId) {
        String sql = "SELECT client_id, expires_at FROM record_locks WHERE record_id = ?";
        try (Connection conn = DBConnection.getLockManager();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setLong(1, recordId);
            try (ResultSet rs = ps.executeQuery()) {
                if (rs.next()) {
                    return rs.getString("client_id") + " (hết hạn: " + rs.getTimestamp("expires_at") + ")";
                }
            }
        } catch (SQLException ignored) { }
        return "CLIENT khác";
    }

    /** Lấy token đang giữ của chính client này (tiện cho demo). */
    public String findToken(long recordId, String clientId) {
        String sql = "SELECT lock_token FROM record_locks WHERE record_id = ? AND client_id = ?";
        try (Connection conn = DBConnection.getLockManager();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setLong(1, recordId);
            ps.setString(2, clientId);
            try (ResultSet rs = ps.executeQuery()) {
                if (rs.next()) return rs.getString("lock_token");
            }
        } catch (SQLException ignored) { }
        return "";
    }

    public boolean checkConnection(String type) {
        try (Connection conn = DBConnection.getConnection(type)) {
            return conn != null && conn.isValid(2);
        } catch (Exception e) {
            return false;
        }
    }

    public int countRecords(String type) {
        try (Connection conn = DBConnection.getConnection(type);
             Statement st = conn.createStatement();
             ResultSet rs = st.executeQuery("SELECT COUNT(*) FROM records")) {
            if (rs.next()) return rs.getInt(1);
        } catch (SQLException e) {
            return -1;
        }
        return -1;
    }

    /** Kiểm tra trạng thái replication trên Server 2 (nếu có quyền). */
    public String replicationStatus(String type) {
        try (Connection conn = DBConnection.getConnection(type);
             Statement st = conn.createStatement();
             ResultSet rs = st.executeQuery("SHOW REPLICA STATUS")) {
            if (rs.next()) {
                return "IO=" + rs.getString("Replica_IO_Running")
                     + ", SQL=" + rs.getString("Replica_SQL_Running")
                     + ", Behind=" + rs.getString("Seconds_Behind_Source");
            }
            return "Không có cấu hình replica (đây có thể là Server 1)";
        } catch (SQLException e) {
            return "Không đọc được trạng thái replica: " + e.getMessage();
        }
    }
}
