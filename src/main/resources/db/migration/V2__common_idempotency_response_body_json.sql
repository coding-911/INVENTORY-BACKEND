-- 중복 요청 키의 처음 응답은 받은 그대로 보관한다 (2026-11-25).
-- jsonb는 키 순서를 바꿔서 다시 보낸 응답의 필드 순서가 처음과 달라진다. 응답 안을 검색하지 않으므로 json으로 둔다.
ALTER TABLE common.idempotency_keys
    ALTER COLUMN response_body TYPE json USING response_body::json;
