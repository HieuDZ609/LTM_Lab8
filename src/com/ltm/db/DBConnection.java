package com.ltm.db;

import java.io.File;
import java.io.FileInputStream;
import java.io.InputStream;
import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.SQLException;
import java.util.Properties;

/**
 * Đọc config.properties và tạo kết nối JDBC.
 * Có connectTimeout ngắn để app không bị treo khi IP Server 2 sai.
 */
public class DBConnection {

    private static final Properties props = new Properties();
    private static final String PLACEHOLDER = "IP_MAY_BAN_BE";

    static {
        String[] candidates = {"config.properties", "../config.properties", "DeTai_SyncDB_2Server_2Client/config.properties"};
        boolean loaded = false;
        for (String path : candidates) {
            File f = new File(path);
            if (f.isFile()) {
                try (FileInputStream fis = new FileInputStream(f)) {
                    props.load(new java.io.InputStreamReader(fis, java.nio.charset.StandardCharsets.UTF_8));
                    loaded = true;
                    break;
                } catch (Exception ignored) { }
            }
        }
        if (!loaded) {
            try (InputStream is = DBConnection.class.getClassLoader().getResourceAsStream("config.properties")) {
                if (is != null) {
                    props.load(new java.io.InputStreamReader(is, java.nio.charset.StandardCharsets.UTF_8));
                    loaded = true;
                }
            } catch (Exception ignored) { }
        }
        try {
            Class.forName("com.mysql.cj.jdbc.Driver");
        } catch (ClassNotFoundException e) {
            System.err.println("Không tìm thấy MySQL Connector/J trong classpath!");
        }
    }

    public static boolean isPlaceholder(String type) {
        return PLACEHOLDER.equals(props.getProperty(type + ".host", ""));
    }

    public static Connection getConnection(String type) throws SQLException {
        String host = props.getProperty(type + ".host");
        String port = props.getProperty(type + ".port", "3306");
        String db = props.getProperty(type + ".db");
        String user = props.getProperty(type + ".user");
        String pass = props.getProperty(type + ".pass");

        if (host == null || host.trim().isEmpty()) {
            throw new SQLException("Chưa cấu hình " + type + ".host trong config.properties");
        }
        if (isPlaceholder(type)) {
            throw new SQLException("Chưa điền IP thật cho " + type + ".host (đang là " + PLACEHOLDER + ")");
        }

        String url = "jdbc:mysql://" + host.trim() + ":" + port + "/" + db
                + "?useSSL=false&allowPublicKeyRetrieval=true"
                + "&serverTimezone=Asia/Ho_Chi_Minh"
                + "&connectTimeout=3000&socketTimeout=5000"
                + "&tcpKeepAlive=true&autoReconnect=true";
        return DriverManager.getConnection(url, user, pass);
    }

    public static Connection getLockManager() throws SQLException { return getConnection("lockManager"); }
    public static Connection getServer1() throws SQLException { return getConnection("server1"); }
    public static Connection getServer2() throws SQLException { return getConnection("server2"); }

    public static String getProperty(String key) { return props.getProperty(key); }

    public static String getProperty(String key, String def) {
        return props.getProperty(key, def);
    }

    public static String getRole() { return props.getProperty("ROLE", "CLIENT2"); }

    public static String getClientId() { return props.getProperty("CLIENT_ID", "CLIENT-2"); }

    public static int getLeaseMinutes() {
        try {
            return Math.max(1, Integer.parseInt(props.getProperty("lease.minutes", "2").trim()));
        } catch (Exception e) {
            return 2;
        }
    }
}
