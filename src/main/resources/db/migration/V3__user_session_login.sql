-- 로그인을 OAuth2 토큰에서 서버 세션으로 바꾼다 (2026-11-25, ADR "인증 방식: 세션 로그인").
-- 세션은 Spring Session JDBC가 이 두 테이블에 저장한다. 컬럼은 spring-session-jdbc 4.1의 schema-postgresql.sql과 같고,
-- 이름만 소문자·auth 스키마·이 프로젝트의 제약 이름 규칙으로 바꿨다.
DROP TABLE auth.oauth2_authorization;

CREATE TABLE auth.spring_session (
    primary_id char(36) NOT NULL,
    session_id char(36) NOT NULL,
    creation_time bigint NOT NULL,
    last_access_time bigint NOT NULL,
    max_inactive_interval int NOT NULL,
    expiry_time bigint NOT NULL,
    principal_name varchar(100),
    CONSTRAINT pk_spring_session PRIMARY KEY (primary_id)
);

CREATE UNIQUE INDEX ux_spring_session_session_id ON auth.spring_session (session_id);
CREATE INDEX ix_spring_session_expiry_time ON auth.spring_session (expiry_time);
CREATE INDEX ix_spring_session_principal_name ON auth.spring_session (principal_name);

CREATE TABLE auth.spring_session_attributes (
    session_primary_id char(36) NOT NULL,
    attribute_name varchar(200) NOT NULL,
    attribute_bytes bytea NOT NULL,
    CONSTRAINT pk_spring_session_attributes PRIMARY KEY (session_primary_id, attribute_name),
    CONSTRAINT fk_spring_session_attributes_session_primary_id FOREIGN KEY (session_primary_id)
        REFERENCES auth.spring_session (primary_id) ON DELETE CASCADE
);

COMMENT ON TABLE auth.spring_session IS '로그인 세션(Spring Session JDBC)';
COMMENT ON COLUMN auth.spring_session.primary_id IS '내부 ID';
COMMENT ON COLUMN auth.spring_session.session_id IS '세션 ID(쿠키 값). 로그인할 때 바뀐다';
COMMENT ON COLUMN auth.spring_session.creation_time IS '만든 시각(epoch 밀리초)';
COMMENT ON COLUMN auth.spring_session.last_access_time IS '마지막 요청 시각(epoch 밀리초)';
COMMENT ON COLUMN auth.spring_session.max_inactive_interval IS '요청이 없으면 끝나는 시간(초)';
COMMENT ON COLUMN auth.spring_session.expiry_time IS '만료 시각(epoch 밀리초)';
COMMENT ON COLUMN auth.spring_session.principal_name IS '사용자 ID(auth.users.id)';
COMMENT ON TABLE auth.spring_session_attributes IS '로그인 세션 속성';
COMMENT ON COLUMN auth.spring_session_attributes.session_primary_id IS '세션';
COMMENT ON COLUMN auth.spring_session_attributes.attribute_name IS '속성 이름';
COMMENT ON COLUMN auth.spring_session_attributes.attribute_bytes IS '속성 값(직렬화)';
COMMENT ON COLUMN auth.users.tokens_valid_after IS '세션 무효 기준 시각. 이보다 먼저 로그인한 세션은 끊는다';
