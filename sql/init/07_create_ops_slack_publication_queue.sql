BEGIN;

CREATE SCHEMA IF NOT EXISTS ops;

REVOKE ALL ON SCHEMA ops FROM PUBLIC;

CREATE TABLE IF NOT EXISTS ops.slack_publication_queue (
    activity_id BIGINT PRIMARY KEY,
    employee_id INTEGER NOT NULL,
    activity_start_datetime TIMESTAMP WITH TIME ZONE NOT NULL,
    sport_type TEXT NOT NULL,
    distance_meters NUMERIC,
    elapsed_seconds INTEGER,
    activity_comment TEXT,
    source_system TEXT,

    publication_status TEXT NOT NULL DEFAULT 'PENDING',
    attempt_count INTEGER NOT NULL DEFAULT 0,
    claimed_at TIMESTAMP WITH TIME ZONE,
    published_at TIMESTAMP WITH TIME ZONE,
    slack_channel_id TEXT,
    slack_message_ts TEXT,
    slack_permalink TEXT,
    last_error TEXT,

    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT ck_slack_publication_status
        CHECK (
            publication_status IN (
                'PENDING',
                'IN_PROGRESS',
                'PUBLISHED',
                'ERROR'
            )
        ),

    CONSTRAINT ck_slack_publication_attempt_count
        CHECK (attempt_count >= 0)
);

CREATE INDEX IF NOT EXISTS idx_slack_publication_queue_status
    ON ops.slack_publication_queue (
        publication_status,
        activity_start_datetime,
        activity_id
    );

GRANT USAGE ON SCHEMA ops TO :"app_user";

GRANT SELECT, INSERT, UPDATE, DELETE ON ops.slack_publication_queue TO :"app_user";

COMMIT;
