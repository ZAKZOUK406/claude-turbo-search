-- Entity Metadata Schema
-- Tri-layer symbolic index for structured entity lookups

-- Entity metadata: tracks named entities extracted from memory entries
CREATE TABLE IF NOT EXISTS entity_metadata (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    entity TEXT NOT NULL,                -- e.g., "src/auth/middleware.ts", "express", "AuthService"
    entity_type TEXT NOT NULL,           -- file, package, function, concept
    source_type TEXT NOT NULL,           -- session, knowledge, fact
    source_id INTEGER NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(entity, entity_type, source_type, source_id)
);

-- Relations between memory entries
CREATE TABLE IF NOT EXISTS entry_relations (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    from_type TEXT NOT NULL,             -- session, knowledge, fact
    from_id INTEGER NOT NULL,
    to_type TEXT NOT NULL,               -- session, knowledge, fact
    to_id INTEGER NOT NULL,
    relation TEXT NOT NULL DEFAULT 'related_to',  -- related_to, supersedes, extends, conflicts
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(from_type, from_id, to_type, to_id, relation)
);

-- Indexes for fast entity lookups
CREATE INDEX IF NOT EXISTS idx_entity_name ON entity_metadata(entity);
CREATE INDEX IF NOT EXISTS idx_entity_type ON entity_metadata(entity_type);
CREATE INDEX IF NOT EXISTS idx_entity_source ON entity_metadata(source_type, source_id);

-- Indexes for relation lookups
CREATE INDEX IF NOT EXISTS idx_relation_from ON entry_relations(from_type, from_id);
CREATE INDEX IF NOT EXISTS idx_relation_to ON entry_relations(to_type, to_id);
