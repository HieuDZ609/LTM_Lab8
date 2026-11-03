package com.ltm.ui;

import com.ltm.db.DBConnection;
import com.ltm.model.Record;
import com.ltm.service.RecordService;

import javax.swing.*;
import javax.swing.border.EmptyBorder;
import javax.swing.table.DefaultTableModel;
import java.awt.*;
import java.time.LocalTime;
import java.util.List;

public class MainFrame extends JFrame {

    private final RecordService service = new RecordService();

    private JTable tblRecords;
    private DefaultTableModel tableModel;

    private JComboBox<Record> cbLock;      // chỉ bản ghi đang rảnh
    private JComboBox<Record> cbUnlock;    // tất cả bản ghi
    private JTextField txtClientId;
    private JTextField txtToken;
    private JLabel lblLeaseInfo;

    private JTextArea txtLog;

    private JLabel lblS1, lblS2, lblSync, lblReplica;
    private JLabel lblStatusBar;

    public MainFrame() {
        setTitle("ĐỒNG BỘ CSDL 2 SERVER – 2 CLIENT  |  Lock Manager: Server 1");
        setDefaultCloseOperation(JFrame.EXIT_ON_CLOSE);
        setMinimumSize(new Dimension(980, 660));
        setSize(1060, 700);

        initUI();
        setLocationRelativeTo(null);

        log("Ứng dụng khởi động. ROLE=" + DBConnection.getRole()
                + " | CLIENT_ID=" + DBConnection.getClientId());
        log("Lock Manager = " + DBConnection.getProperty("lockManager.host")
                + ":" + DBConnection.getProperty("lockManager.port"));
        refreshAll();
        checkConnections();
    }

    // ==================== UI ====================

    private void initUI() {
        JTabbedPane tabs = new JTabbedPane();
        tabs.addTab("1. Danh sách bản ghi", buildRecordsTab());
        tabs.addTab("2. Khóa / Giải phóng", buildLockTab());
        tabs.addTab("3. Đồng bộ & Kết nối", buildConnectionTab());
        tabs.addTab("4. Nhật ký", buildLogTab());

        JPanel header = buildHeader();
        JPanel status = buildStatusBar();

        setLayout(new BorderLayout());
        add(header, BorderLayout.NORTH);
        add(tabs, BorderLayout.CENTER);
        add(status, BorderLayout.SOUTH);
    }

    private JPanel buildHeader() {
        JPanel p = new JPanel(new FlowLayout(FlowLayout.LEFT, 14, 8));
        p.setBorder(BorderFactory.createMatteBorder(0, 0, 1, 0, new Color(210, 210, 210)));
        p.setBackground(new Color(248, 249, 251));

        JLabel title = new JLabel("Đồng bộ CSDL 2 Server – 2 Client");
        title.setFont(title.getFont().deriveFont(Font.BOLD, 15f));

        JLabel role = new JLabel("ROLE: " + DBConnection.getRole());
        role.setForeground(new Color(20, 90, 160));
        JLabel client = new JLabel("CLIENT_ID: " + DBConnection.getClientId());
        client.setForeground(new Color(20, 90, 160));
        JLabel lm = new JLabel("Lock Manager: " + DBConnection.getProperty("lockManager.host"));
        lm.setForeground(new Color(120, 80, 20));

        p.add(title);
        p.add(new JSeparator(SwingConstants.VERTICAL));
        p.add(role);
        p.add(client);
        p.add(lm);
        return p;
    }

    private JPanel buildStatusBar() {
        JPanel p = new JPanel(new FlowLayout(FlowLayout.LEFT, 10, 4));
        p.setBorder(BorderFactory.createMatteBorder(1, 0, 0, 0, new Color(215, 215, 215)));
        lblStatusBar = new JLabel("Sẵn sàng");
        p.add(lblStatusBar);
        return p;
    }

    // ---------- Tab 1 ----------
    private JPanel buildRecordsTab() {
        JPanel p = new JPanel(new BorderLayout(0, 6));
        p.setBorder(new EmptyBorder(8, 8, 8, 8));

        tableModel = new DefaultTableModel(
                new Object[]{"ID", "Mã bản ghi", "Tên bản ghi", "Ngày tạo", "Trạng thái"}, 0) {
            @Override
            public boolean isCellEditable(int r, int c) { return false; }
        };
        tblRecords = new JTable(tableModel);
        tblRecords.setRowHeight(24);
        tblRecords.getTableHeader().setReorderingAllowed(false);
        tblRecords.setSelectionMode(ListSelectionModel.SINGLE_SELECTION);

        p.add(new JScrollPane(tblRecords), BorderLayout.CENTER);

        JPanel bottom = new JPanel(new FlowLayout(FlowLayout.LEFT, 8, 4));
        JButton btnReload = new JButton("Tải lại danh sách");
        JButton btnNew = new JButton("Tạo bản ghi mới");
        JButton btnDelete = new JButton("Xóa bản ghi đã chọn");
        JButton btnPick = new JButton("Chọn bản ghi này để thao tác");

        btnReload.addActionListener(e -> refreshAll());
        btnNew.addActionListener(e -> onCreateRecord());
        btnDelete.addActionListener(e -> onDeleteRecord());
        btnPick.addActionListener(e -> {
            int row = tblRecords.getSelectedRow();
            if (row < 0) {
                JOptionPane.showMessageDialog(this, "Hãy chọn một dòng trong bảng trước.");
                return;
            }
            long id = ((Number) tableModel.getValueAt(row, 0)).longValue();
            selectRecordInCombos(id);
        });

        bottom.add(btnReload);
        bottom.add(btnNew);
        bottom.add(btnDelete);
        bottom.add(btnPick);
        p.add(bottom, BorderLayout.SOUTH);
        return p;
    }

    private void onDeleteRecord() {
        int row = tblRecords.getSelectedRow();
        if (row < 0) {
            JOptionPane.showMessageDialog(this, "Hãy chọn một dòng trong bảng trước.");
            return;
        }
        long rid = ((Number) tableModel.getValueAt(row, 0)).longValue();
        String code = (String) tableModel.getValueAt(row, 1);
        int confirm = JOptionPane.showConfirmDialog(this,
                "Xóa bản ghi " + code + " (ID=" + rid + ")?",
                "Xác nhận xóa", JOptionPane.YES_NO_OPTION, JOptionPane.WARNING_MESSAGE);
        if (confirm != JOptionPane.YES_OPTION) return;
        String res = service.deleteRecord(rid);
        log("DELETE " + code + " -> " + res);
        if (res.startsWith("SUCCESS")) {
            JOptionPane.showMessageDialog(this, res.substring(res.indexOf(':') + 1));
            refreshAll();
        } else {
            JOptionPane.showMessageDialog(this, stripPrefix(res), "Lỗi", JOptionPane.ERROR_MESSAGE);
        }
    }

    private void onCreateRecord() {
        JTextField fCode = new JTextField();
        JTextField fName = new JTextField();
        JPanel form = new JPanel(new GridLayout(2, 2, 6, 6));
        form.add(new JLabel("Mã bản ghi (VD: SV010):"));
        form.add(fCode);
        form.add(new JLabel("Tên bản ghi:"));
        form.add(fName);

        int res = JOptionPane.showConfirmDialog(this, form,
                "Tạo bản ghi mới (ghi tại Lock Manager → đồng bộ sang Server 2)",
                JOptionPane.OK_CANCEL_OPTION, JOptionPane.PLAIN_MESSAGE);
        if (res != JOptionPane.OK_OPTION) return;

        String r = service.createRecord(fCode.getText(), fName.getText());
        log("CREATE '" + fCode.getText().trim() + "' → " + r);

        if (r.startsWith("SUCCESS")) {
            setStatus("Tạo bản ghi thành công, chờ đồng bộ sang Server 2…");
            JOptionPane.showMessageDialog(this, r.substring(r.indexOf(':') + 1),
                    "Thành công", JOptionPane.INFORMATION_MESSAGE);
            refreshAll();
            // kiểm tra đồng bộ sau 1.5s
            Timer t = new Timer(1500, e -> checkSync(true));
            t.setRepeats(false);
            t.start();
        } else {
            setStatus("Tạo thất bại");
            JOptionPane.showMessageDialog(this, stripPrefix(r), "Lỗi", JOptionPane.ERROR_MESSAGE);
        }
    }

    // ---------- Tab 2 ----------
    private JPanel buildLockTab() {
        JPanel root = new JPanel(new GridLayout(1, 2, 10, 10));
        root.setBorder(new EmptyBorder(10, 10, 10, 10));

        // --- Panel khóa ---
        JPanel lockPanel = new JPanel(new GridBagLayout());
        lockPanel.setBorder(BorderFactory.createTitledBorder("CẤP KHÓA (sử dụng bản ghi)"));
        GridBagConstraints c = new GridBagConstraints();
        c.insets = new Insets(6, 6, 6, 6);
        c.fill = GridBagConstraints.HORIZONTAL;
        c.gridx = 0; c.gridy = 0; c.weightx = 0;
        lockPanel.add(new JLabel("Bản ghi đang rảnh:"), c);
        cbLock = new JComboBox<>();
        c.gridx = 1; c.weightx = 1;
        lockPanel.add(cbLock, c);

        c.gridx = 0; c.gridy = 1; c.weightx = 0;
        lockPanel.add(new JLabel("Client ID:"), c);
        txtClientId = new JTextField(DBConnection.getClientId());
        c.gridx = 1; c.weightx = 1;
        lockPanel.add(txtClientId, c);

        JButton btnLock = new JButton("KHÓA BẢN GHI");
        c.gridx = 1; c.gridy = 2;
        lockPanel.add(btnLock, c);

        lblLeaseInfo = new JLabel(" ");
        lblLeaseInfo.setForeground(new Color(90, 90, 90));
        c.gridx = 0; c.gridy = 3; c.gridwidth = 2;
        lockPanel.add(lblLeaseInfo, c);
        c.gridwidth = 1;

        JButton btnRefreshLock = new JButton("Làm mới danh sách");
        c.gridx = 1; c.gridy = 4;
        lockPanel.add(btnRefreshLock, c);

        btnLock.addActionListener(e -> onLock());
        btnRefreshLock.addActionListener(e -> refreshAll());

        // --- Panel giải phóng ---
        JPanel unlockPanel = new JPanel(new GridBagLayout());
        unlockPanel.setBorder(BorderFactory.createTitledBorder("GIẢI PHÓNG KHÓA"));
        GridBagConstraints d = new GridBagConstraints();
        d.insets = new Insets(6, 6, 6, 6);
        d.fill = GridBagConstraints.HORIZONTAL;

        d.gridx = 0; d.gridy = 0; d.weightx = 0;
        unlockPanel.add(new JLabel("Bản ghi:"), d);
        cbUnlock = new JComboBox<>();
        d.gridx = 1; d.weightx = 1;
        unlockPanel.add(cbUnlock, d);

        d.gridx = 0; d.gridy = 1; d.weightx = 0;
        unlockPanel.add(new JLabel("Client ID:"), d);
        JTextField txtUnlockClient = new JTextField(DBConnection.getClientId());
        d.gridx = 1; d.weightx = 1;
        unlockPanel.add(txtUnlockClient, d);

        d.gridx = 0; d.gridy = 2; d.weightx = 0;
        unlockPanel.add(new JLabel("LOCK_TOKEN:"), d);
        txtToken = new JTextField();
        d.gridx = 1; d.weightx = 1;
        unlockPanel.add(txtToken, d);

        JButton btnFillToken = new JButton("Lấy token của tôi");
        d.gridx = 1; d.gridy = 3;
        unlockPanel.add(btnFillToken, d);

        JButton btnUnlock = new JButton("GIẢI PHÓNG BẢN GHI");
        d.gridx = 1; d.gridy = 4;
        unlockPanel.add(btnUnlock, d);

        JLabel hint = new JLabel("<html><i>Chỉ đúng client_id + lock_token mới giải phóng được.</i></html>");
        hint.setForeground(new Color(110, 110, 110));
        d.gridx = 0; d.gridy = 5; d.gridwidth = 2;
        unlockPanel.add(hint, d);

        btnUnlock.addActionListener(e -> onUnlock(txtUnlockClient.getText()));
        btnFillToken.addActionListener(e -> {
            Record r = (Record) cbUnlock.getSelectedItem();
            if (r == null) return;
            String tk = service.findToken(r.getRecordId(), txtUnlockClient.getText().trim());
            if (tk.isEmpty()) {
                JOptionPane.showMessageDialog(this, "Client này không giữ khóa nào trên bản ghi đã chọn.");
            } else {
                txtToken.setText(tk);
            }
        });

        root.add(lockPanel);
        root.add(unlockPanel);
        return root;
    }

    private void onLock() {
        Record r = (Record) cbLock.getSelectedItem();
        if (r == null) {
            JOptionPane.showMessageDialog(this, "Không có bản ghi rảnh để khóa.\nHãy tải lại danh sách.");
            return;
        }
        String clientId = txtClientId.getText().trim();
        String res = service.lockRecord(r.getRecordId(), clientId);

        if (res.startsWith("SUCCESS")) {
            String token = res.substring(res.indexOf(':') + 1);
            txtToken.setText(token);
            log("LOCK " + r.getRecordCode() + " → THÀNH CÔNG (token=" + token + ")");
            setStatus("Đã khóa " + r.getRecordCode() + " cho " + clientId);
            JOptionPane.showMessageDialog(this,
                    "KHÓA THÀNH CÔNG\n\nBản ghi: " + r.getRecordCode()
                            + "\nClient: " + clientId
                            + "\nLOCK_TOKEN: " + token
                            + "\n\nToken đã được điền sẵn ở khung giải phóng.",
                    "Thành công", JOptionPane.INFORMATION_MESSAGE);
        } else {
            log("LOCK " + r.getRecordCode() + " → THẤT BẠI: " + res);
            setStatus("Khóa thất bại");
            JOptionPane.showMessageDialog(this, stripPrefix(res),
                    "Không thể khóa", JOptionPane.WARNING_MESSAGE);
        }
        refreshAll();
    }

    private void onUnlock(String clientId) {
        Record r = (Record) cbUnlock.getSelectedItem();
        if (r == null) {
            JOptionPane.showMessageDialog(this, "Hãy chọn bản ghi cần giải phóng.");
            return;
        }
        String res = service.unlockRecord(r.getRecordId(), clientId.trim(), txtToken.getText());
        log("UNLOCK " + r.getRecordCode() + " bởi " + clientId + " → " + res);
        if (res.startsWith("SUCCESS")) {
            txtToken.setText("");
            setStatus("Đã giải phóng " + r.getRecordCode());
            JOptionPane.showMessageDialog(this, res.substring(res.indexOf(':') + 1),
                    "Thành công", JOptionPane.INFORMATION_MESSAGE);
        } else {
            setStatus("Giải phóng thất bại");
            JOptionPane.showMessageDialog(this, stripPrefix(res), "Lỗi", JOptionPane.ERROR_MESSAGE);
        }
        refreshAll();
    }

    // ---------- Tab 3 ----------
    private JPanel buildConnectionTab() {
        JPanel p = new JPanel(new GridBagLayout());
        p.setBorder(new EmptyBorder(12, 12, 12, 12));
        GridBagConstraints c = new GridBagConstraints();
        c.insets = new Insets(6, 6, 6, 6);
        c.fill = GridBagConstraints.HORIZONTAL;
        c.anchor = GridBagConstraints.WEST;

        lblS1 = new JLabel("-");
        lblS2 = new JLabel("-");
        lblSync = new JLabel("-");
        lblReplica = new JLabel("-");

        int y = 0;
        c.gridx = 0; c.gridy = y; p.add(new JLabel("Server 1 (Lock Manager):"), c);
        c.gridx = 1; p.add(lblS1, c); y++;
        c.gridx = 0; c.gridy = y; p.add(new JLabel("Server 2:"), c);
        c.gridx = 1; p.add(lblS2, c); y++;
        c.gridx = 0; c.gridy = y; p.add(new JLabel("Đồng bộ dữ liệu:"), c);
        c.gridx = 1; p.add(lblSync, c); y++;
        c.gridx = 0; c.gridy = y; p.add(new JLabel("Replication (Server 2):"), c);
        c.gridx = 1; p.add(lblReplica, c); y++;

        JPanel buttons = new JPanel(new FlowLayout(FlowLayout.LEFT, 8, 0));
        JButton btnConn = new JButton("Kiểm tra kết nối");
        JButton btnSync = new JButton("Kiểm tra đồng bộ");
        JButton btnReplica = new JButton("Xem replication");
        buttons.add(btnConn);
        buttons.add(btnSync);
        buttons.add(btnReplica);

        c.gridx = 0; c.gridy = y; c.gridwidth = 2;
        p.add(buttons, c);

        btnConn.addActionListener(e -> checkConnections());
        btnSync.addActionListener(e -> checkSync(false));
        btnReplica.addActionListener(e -> {
            String st = service.replicationStatus("server2");
            lblReplica.setText(st);
            log("Replication Server 2: " + st);
        });
        return p;
    }

    private void checkConnections() {
        boolean lm = service.checkConnection("lockManager");
        boolean s1 = service.checkConnection("server1");
        boolean s2 = service.checkConnection("server2");

        lblS1.setText((lm ? "OK" : "FAIL") + "  (" + DBConnection.getProperty("lockManager.host") + ")");
        lblS1.setForeground(lm ? new Color(0, 128, 0) : Color.RED);

        String s2host = DBConnection.getProperty("server2.host");
        if ("IP_MAY_BAN_BE".equals(s2host)) {
            lblS2.setText("Chưa cấu hình IP Server 2 trong config.properties");
            lblS2.setForeground(new Color(180, 100, 0));
        } else {
            lblS2.setText((s2 ? "OK" : "FAIL") + "  (" + s2host + ")");
            lblS2.setForeground(s2 ? new Color(0, 128, 0) : Color.RED);
        }
        log("Kết nối → LockManager=" + lm + ", Server1=" + s1 + ", Server2=" + s2);
    }

    private void checkSync(boolean fromCreate) {
        int n1 = service.countRecords("lockManager");
        int n2 = service.countRecords("server2");
        String msg;
        if (n1 < 0 || n2 < 0) {
            msg = "Không đọc được số bản ghi (Server 2 chưa cấu hình?)";
            lblSync.setForeground(new Color(180, 100, 0));
        } else if (n1 == n2) {
            msg = "ĐÃ ĐỒNG BỘ  (Server 1: " + n1 + " = Server 2: " + n2 + ")";
            lblSync.setForeground(new Color(0, 128, 0));
        } else {
            msg = "CHƯA ĐỒNG BỘ  (Server 1: " + n1 + " ≠ Server 2: " + n2 + ")";
            lblSync.setForeground(Color.RED);
        }
        lblSync.setText(msg);
        log("Đồng bộ → " + msg);
        if (!fromCreate) {
            JOptionPane.showMessageDialog(this, msg, "Kiểm tra đồng bộ", JOptionPane.INFORMATION_MESSAGE);
        }
    }

    // ---------- Tab 4 ----------
    private JPanel buildLogTab() {
        JPanel p = new JPanel(new BorderLayout(0, 6));
        p.setBorder(new EmptyBorder(8, 8, 8, 8));
        txtLog = new JTextArea();
        txtLog.setEditable(false);
        txtLog.setFont(new Font(Font.MONOSPACED, Font.PLAIN, 12));
        p.add(new JScrollPane(txtLog), BorderLayout.CENTER);

        JButton btnClear = new JButton("Xóa nhật ký");
        btnClear.addActionListener(e -> txtLog.setText(""));
        JPanel b = new JPanel(new FlowLayout(FlowLayout.LEFT, 8, 0));
        b.add(btnClear);
        p.add(b, BorderLayout.SOUTH);
        return p;
    }

    // ==================== Helpers ====================

    private void refreshAll() {
        try {
            List<Record> list = service.getAllRecords();
            tableModel.setRowCount(0);
            for (Record r : list) {
                tableModel.addRow(new Object[]{
                        r.getRecordId(), r.getRecordCode(), r.getRecordName(),
                        r.getCreatedAt(), r.getStatus()});
            }

            cbLock.removeAllItems();
            cbUnlock.removeAllItems();
            for (Record r : list) {
                cbUnlock.addItem(r);
                if (r.isFree()) cbLock.addItem(r);
            }
            log("Đã tải " + list.size() + " bản ghi (rảnh: " + cbLock.getItemCount() + ")");
            lblLeaseInfo.setText("Lease mặc định: " + DBConnection.getLeaseMinutes() + " phút");
        } catch (Exception e) {
            log("Lỗi tải danh sách: " + e.getMessage());
            setStatus("Lỗi tải danh sách – kiểm tra kết nối MySQL");
        }
    }

    private void selectRecordInCombos(long recordId) {
        for (int i = 0; i < cbUnlock.getItemCount(); i++) {
            if (cbUnlock.getItemAt(i).getRecordId() == recordId) {
                cbUnlock.setSelectedIndex(i);
                break;
            }
        }
        for (int i = 0; i < cbLock.getItemCount(); i++) {
            if (cbLock.getItemAt(i).getRecordId() == recordId) {
                cbLock.setSelectedIndex(i);
                break;
            }
        }
        setStatus("Đã chọn bản ghi ID=" + recordId + " ở tab Khóa/Giải phóng");
    }

    private String stripPrefix(String res) {
        int i = res.indexOf(':');
        return i >= 0 ? res.substring(i + 1) : res;
    }

    private void setStatus(String s) {
        if (lblStatusBar != null) lblStatusBar.setText(s);
    }

    private void log(String s) {
        if (txtLog == null) return;
        txtLog.append("[" + LocalTime.now().withNano(0) + "] " + s + "\n");
        txtLog.setCaretPosition(txtLog.getDocument().getLength());
    }
}
