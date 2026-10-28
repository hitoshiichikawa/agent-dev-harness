-- name: ListExamples :many
SELECT id, name, created_at
FROM examples
WHERE (sqlc.narg('after')::timestamptz IS NULL OR created_at < sqlc.narg('after'))
ORDER BY created_at DESC
LIMIT sqlc.arg('limit');

-- name: GetExample :one
SELECT id, name, created_at
FROM examples
WHERE id = $1;

-- name: CreateExample :one
INSERT INTO examples (name)
VALUES ($1)
RETURNING id, name, created_at;
