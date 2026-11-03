package com.ltm.model;

import java.sql.Timestamp;

public class Record {
    private long recordId;
    private String recordCode;
    private String recordName;
    private Timestamp createdAt;
    private String status;

    public Record(long recordId, String recordCode, String recordName, Timestamp createdAt) {
        this.recordId = recordId;
        this.recordCode = recordCode;
        this.recordName = recordName;
        this.createdAt = createdAt;
        this.status = "Rảnh";
    }

    public long getRecordId() { return recordId; }
    public String getRecordCode() { return recordCode; }
    public String getRecordName() { return recordName; }
    public Timestamp getCreatedAt() { return createdAt; }
    public String getStatus() { return status; }
    public void setStatus(String status) { this.status = status; }

    public boolean isFree() {
        return status == null || status.equals("Rảnh");
    }

    @Override
    public String toString() {
        return recordCode + " - " + recordName + " [" + status + "]";
    }
}
