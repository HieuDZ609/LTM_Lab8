package com.ltm.model;

import java.sql.Timestamp;

public class RecordLock {
    private long recordId;
    private String clientId;
    private String lockToken;
    private Timestamp lockedAt;
    private Timestamp expiresAt;

    public RecordLock(long recordId, String clientId, String lockToken, Timestamp lockedAt, Timestamp expiresAt) {
        this.recordId = recordId;
        this.clientId = clientId;
        this.lockToken = lockToken;
        this.lockedAt = lockedAt;
        this.expiresAt = expiresAt;
    }

    public long getRecordId() { return recordId; }
    public String getClientId() { return clientId; }
    public String getLockToken() { return lockToken; }
    public Timestamp getLockedAt() { return lockedAt; }
    public Timestamp getExpiresAt() { return expiresAt; }
}
