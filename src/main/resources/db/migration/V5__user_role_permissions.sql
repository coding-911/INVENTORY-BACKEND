-- 역할·권한 체계를 바꾼다 (2026-11-26, 확정 사항 #106, 권한 매트릭스 1절, 테이블 정의서 3.2).
-- 권한 13개를 서로 겹치지 않게 두고, 역할은 권한을 고른 묶음이며, 계정은 역할 하나를 갖는다.
-- 예전 user_roles(계정별 역할 여러 개)·user_permissions(계정별 금액 권한)는 없앤다.

-- 1. 권한 목록. 코드가 검사하므로 마이그레이션으로만 넣는다(코드의 Permission과 같은지 테스트한다).
CREATE TABLE auth.permissions (
    code varchar(30) NOT NULL,
    name varchar(50) NOT NULL,
    description varchar(200) NOT NULL,
    sort_order smallint NOT NULL,
    CONSTRAINT pk_permissions PRIMARY KEY (code)
);

COMMENT ON TABLE auth.permissions IS '권한 (시스템이 정함, 화면에서 추가·삭제하지 않음)';
COMMENT ON COLUMN auth.permissions.code IS '권한 코드';
COMMENT ON COLUMN auth.permissions.name IS '권한 이름';
COMMENT ON COLUMN auth.permissions.description IS '이 권한으로 할 수 있는 일';
COMMENT ON COLUMN auth.permissions.sort_order IS '보여 주는 순서';

INSERT INTO auth.permissions (code, name, description, sort_order) VALUES
    ('PARTNER_MANAGE', '거래처 관리', '거래처·담당자 등록·수정·삭제', 1),
    ('PRODUCT_MANAGE', '제품 관리', '제품 등록·수정·삭제', 2),
    ('MASTER_MANAGE', '기준 정보 관리', '품목군·창고·위치·통화·구성 묶음 관리, 제품 사용 중지·다시 사용', 3),
    ('DOCUMENT_MANAGE', '거래 문서 관리', '프로젝트·거래 문서 등록·수정·확정·취소·삭제, 비교·복사, 첨부 올리기·떼기', 4),
    ('STOCK_OPERATE', '재고 처리', '입고·출고·이동·검수·배정·납품·반품·교체·대차·실사·수리·보증, 처리 취소·정정, 폐기·대여 출고 요청', 5),
    ('STOCK_ADJUST', '재고 조정', '재고 조정, 초기 재고 넣기, 기준일 이전 등록(납품 장비·처리 수량)', 6),
    ('APPROVE', '승인', '승인·반려·사후 확인, 승인·확인 대기함 전체 보기', 7),
    ('CLOSING', '마감', '월 마감·해제, 거래 품목 잔량 마감', 8),
    ('RECORD_CORRECT', '기록 정정', '7일보다 지난 날짜, 실사 중 범위 처리, 확정 문서의 프로젝트·거래처 변경, 이력 있는 제품의 Item Code 변경, 납품한 장비의 시리얼 변경, 정산 방식 바꾸기', 9),
    ('AUDIT_VIEW', '감사 조회', '정합성 점검 결과 보기·지금 실행, 통합 변경 이력, 제품 변경 이력', 10),
    ('USER_MANAGE', '계정·역할 관리', '계정 목록·하나·만들기·수정·삭제, 비밀번호 초기화, 역할 만들기·수정·삭제', 11),
    ('COST_VIEW', '금액 보기', '응답의 금액 필드, 금액 이력·부대비용·마진·평가액 조회, 첨부 열기·내려받기', 12),
    ('COST_EDIT', '금액 수정', '단가·부대비용·대여료·초기 재고 단가 넣기·고치기·비우기', 13);

-- 2. 역할. 관리자가 만들고 고치므로 [AUD]·[DEL]·version을 둔다.
--    마이그레이션으로 넣는 기본 역할은 만든 사람이 없어 created_by를 비워 둔다(그래서 NULL 허용).
ALTER TABLE auth.roles
    ALTER COLUMN name TYPE varchar(50),
    ADD COLUMN description varchar(200),
    ADD COLUMN created_at timestamptz NOT NULL DEFAULT now(),
    ADD COLUMN created_by uuid,
    ADD COLUMN updated_at timestamptz,
    ADD COLUMN updated_by uuid,
    ADD COLUMN version integer NOT NULL DEFAULT 0,
    ADD COLUMN deleted_at timestamptz,
    ADD COLUMN deleted_by uuid,
    ADD CONSTRAINT ck_roles_code CHECK (code ~ '^[A-Z][A-Z0-9_]*$');

COMMENT ON COLUMN auth.roles.code IS '역할 코드 (만든 뒤 바꾸지 않음, 대문자·숫자·밑줄)';
COMMENT ON COLUMN auth.roles.name IS '역할 이름';
COMMENT ON COLUMN auth.roles.description IS '설명';
COMMENT ON COLUMN auth.roles.created_at IS '만든 시각';
COMMENT ON COLUMN auth.roles.created_by IS '만든 사람 (기본 역할은 NULL)';
COMMENT ON COLUMN auth.roles.updated_at IS '고친 시각';
COMMENT ON COLUMN auth.roles.updated_by IS '고친 사람';
COMMENT ON COLUMN auth.roles.version IS '낙관적 잠금 버전';
COMMENT ON COLUMN auth.roles.deleted_at IS '삭제 시각 (소프트 삭제)';
COMMENT ON COLUMN auth.roles.deleted_by IS '삭제한 사람';

UPDATE auth.roles SET description = '모든 권한. 고치거나 지울 수 없다' WHERE code = 'ADMIN';

INSERT INTO auth.roles (code, name, description) VALUES
    ('OPERATOR_BASIC', '일반 운영자', '거래처·제품·거래 문서 관리와 재고 처리'),
    ('OPERATOR_COST_VIEW', '영업 운영자', '일반 운영자 + 금액 보기'),
    ('OPERATOR_COST_EDIT', '정산 운영자', '일반 운영자 + 금액 보기·수정'),
    ('USER_BASIC', '일반 사용자', '보기만 한다(금액 제외)'),
    ('USER_COST_VIEW', '회계 사용자', '보기만 한다(금액 포함)');

-- 3. 역할에 넣은 권한
CREATE TABLE auth.role_permissions (
    role_id uuid NOT NULL,
    permission_code varchar(30) NOT NULL,
    CONSTRAINT pk_role_permissions PRIMARY KEY (role_id, permission_code),
    CONSTRAINT fk_role_permissions_role_id FOREIGN KEY (role_id) REFERENCES auth.roles (id),
    CONSTRAINT fk_role_permissions_permission_code FOREIGN KEY (permission_code) REFERENCES auth.permissions (code)
);

COMMENT ON TABLE auth.role_permissions IS '역할에 넣은 권한';
COMMENT ON COLUMN auth.role_permissions.role_id IS '역할';
COMMENT ON COLUMN auth.role_permissions.permission_code IS '권한';

INSERT INTO auth.role_permissions (role_id, permission_code)
SELECT r.id, p.code
FROM auth.roles r
JOIN auth.permissions p ON
    r.code = 'ADMIN'
    OR (r.code LIKE 'OPERATOR\_%' AND p.code IN ('PARTNER_MANAGE', 'PRODUCT_MANAGE', 'DOCUMENT_MANAGE', 'STOCK_OPERATE'))
    OR (r.code IN ('OPERATOR_COST_VIEW', 'OPERATOR_COST_EDIT', 'USER_COST_VIEW') AND p.code = 'COST_VIEW')
    OR (r.code = 'OPERATOR_COST_EDIT' AND p.code = 'COST_EDIT');

-- 4. 계정은 역할 하나. 예전 역할·금액 권한을 기본 역할로 옮긴다.
--    역할이 여럿이면 가장 큰 것(관리자 > 입력자 > 조회자), 없으면 일반 사용자.
--    조회자에게 금액 수정이 있었으면(#105 전 데이터) 금액 보기만 남긴다: 조회자 역할로는 어차피 고칠 수 없었다.
ALTER TABLE auth.users ADD COLUMN role_id uuid;

COMMENT ON COLUMN auth.users.role_id IS '역할 (계정마다 하나)';

WITH old AS (
    SELECT u.id,
           EXISTS (SELECT 1 FROM auth.user_roles ur JOIN auth.roles r ON r.id = ur.role_id
                   WHERE ur.user_id = u.id AND r.code = 'ADMIN') AS is_admin,
           EXISTS (SELECT 1 FROM auth.user_roles ur JOIN auth.roles r ON r.id = ur.role_id
                   WHERE ur.user_id = u.id AND r.code = 'OPERATOR') AS is_operator,
           EXISTS (SELECT 1 FROM auth.user_permissions p
                   WHERE p.user_id = u.id AND p.permission = 'COST_VIEW') AS cost_view,
           EXISTS (SELECT 1 FROM auth.user_permissions p
                   WHERE p.user_id = u.id AND p.permission = 'COST_EDIT') AS cost_edit
    FROM auth.users u
)
UPDATE auth.users u
SET role_id = (SELECT r.id FROM auth.roles r WHERE r.code = CASE
        WHEN old.is_admin THEN 'ADMIN'
        WHEN old.is_operator AND old.cost_edit THEN 'OPERATOR_COST_EDIT'
        WHEN old.is_operator AND old.cost_view THEN 'OPERATOR_COST_VIEW'
        WHEN old.is_operator THEN 'OPERATOR_BASIC'
        WHEN old.cost_view OR old.cost_edit THEN 'USER_COST_VIEW'
        ELSE 'USER_BASIC' END)
FROM old
WHERE old.id = u.id;

ALTER TABLE auth.users
    ALTER COLUMN role_id SET NOT NULL,
    ADD CONSTRAINT fk_users_role_id FOREIGN KEY (role_id) REFERENCES auth.roles (id);

-- 역할을 지우기 전에 그 역할인 계정이 있는지 본다(R4)
CREATE INDEX ix_users_role_id ON auth.users (role_id);

DROP TABLE auth.user_permissions;
DROP TABLE auth.user_roles;

-- 예전 역할은 옮긴 뒤 쓰는 곳이 없다. 기본 역할로 대체된 것이라 이력으로 남기지 않고 지운다.
DELETE FROM auth.roles WHERE code IN ('OPERATOR', 'VIEWER');

-- 코드·이름은 삭제된 것을 빼고 겹치지 않는다
CREATE UNIQUE INDEX ux_roles_code ON auth.roles (code) WHERE deleted_at IS NULL;
CREATE UNIQUE INDEX ux_roles_name ON auth.roles (name) WHERE deleted_at IS NULL;
