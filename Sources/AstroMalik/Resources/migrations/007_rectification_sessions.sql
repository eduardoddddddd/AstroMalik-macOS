CREATE TABLE IF NOT EXISTS rectification_sessions (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    base_chart_id TEXT,
    session_json BLOB NOT NULL,
    result_json BLOB,
    narrative_json BLOB,
    created_at REAL NOT NULL,
    updated_at REAL NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_rectification_sessions_updated
ON rectification_sessions(updated_at DESC);

CREATE TABLE IF NOT EXISTS rectification_analysis_versions (
    id TEXT PRIMARY KEY,
    session_id TEXT NOT NULL,
    version INTEGER NOT NULL,
    result_json BLOB NOT NULL,
    narrative_json BLOB,
    created_at REAL NOT NULL,
    FOREIGN KEY(session_id) REFERENCES rectification_sessions(id) ON DELETE CASCADE
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_rectification_versions_session_version
ON rectification_analysis_versions(session_id, version);
