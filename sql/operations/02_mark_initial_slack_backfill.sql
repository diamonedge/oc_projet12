BEGIN;

WITH ranked_pending_activities AS (

    SELECT
        activity_id,

        row_number() over (
            order by
                activity_start_datetime desc,
                activity_id desc
        ) as pending_rank

    FROM ops.slack_publication_queue

    WHERE publication_status = 'PENDING'

)

UPDATE ops.slack_publication_queue as queue

SET
    publication_status = 'BACKFILLED',
    claimed_at = null,
    last_error = null,
    updated_at = current_timestamp

FROM ranked_pending_activities as ranked

WHERE queue.activity_id = ranked.activity_id
  AND ranked.pending_rank > :'pending_batch_size'::integer;

COMMIT;
