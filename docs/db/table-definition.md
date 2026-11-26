# 테이블 정의서

> 원본(노션): https://app.notion.com/p/408b82ca31e58080bd5deb903f3026c6  
> 내보낸 날짜: 2026-11-26. **노션이 원본이다.** 이 파일과 노션이 다르면 노션을 따른다.

> 🗄️ PostgreSQL 기준 테이블 정의. 근거: [요구사항 정의서](https://app.notion.com/p/408b82ca31e58037816bdbd3754b6bab) 6.1절 기존 설계 객체, [재고 원장 처리 규칙](https://app.notion.com/p/53340b01efa54f16a6217503509ca182), [디렉토리 구조](https://app.notion.com/p/408b82ca31e5802da847f03723e75a89), 기술적 의사 결정 기록.

> 🎨 **파란색** = 정의서 v1.1 이후 논의로 새로 추가한 테이블·컬럼. 검은색 = 정의서 6.1절 기존 설계 객체(products, warehouses, warehouse_locations, stock_transactions, low_data, v_current_stock)에서 이어진 부분. 협의 이슈가 확정되면 해당 테이블을 수정한다 (7절).

## 0. DDL 파일

처음부터 모든 제약을 걸지 않고, 서비스 테스트를 마친 뒤 나머지 제약을 추가한다. 다만 서비스 로직이 기대거나 재고·수량이 틀어지는 것을 막는 핵심 제약은 처음부터 둔다.

(첨부 파일: `asset_v1_create.sql` → 이 저장소의 `docs/db/ddl/`)

(첨부 파일: `asset_v2_constraints.sql` → 이 저장소의 `docs/db/ddl/`)

(첨부 파일: `asset_prod_full.sql` → 이 저장소의 `docs/db/ddl/`)

(첨부 파일: `asset_schema_erdcloud_mysql.sql` → 이 저장소의 `docs/db/ddl/`)

| 파일 | 용도 | 내용 |
|---|---|---|
| `asset_v1_create.sql` | ① 처음 생성용 (개발·테스트 DB) | 스키마, 테이블, PK·FK·NOT NULL·기본값, 조회 인덱스, 주석, 초기 데이터 + 핵심 제약 26개 + 나중 마이그레이션(V3·V5)이 처음부터 건 제약 4개. Flyway V1~V5를 적용한 DB와 구조·초기 데이터가 같다(2026-11-26) |
| `asset_v2_constraints.sql` | ② 추후 수정용 (서비스 테스트 후) | v1에서 미룬 제약 107개(2026-11-26 역할·권한 체계로 auth 제약 2개가 빠짐, 코드 목록 CHECK, 조건부 CHECK, 업무 키 UNIQUE, 부분 유니크) + 보강 제안 P1–P5 11건을 ALTER로 추가 |
| `asset_prod_full.sql` | ③ 운영 최종본 | v1 + v2를 한 파일로 합친 것. 2026-11-24 Flyway를 도입해 운영 DB도 마이그레이션으로 만들므로, 이 파일은 v2까지 다 적용한 최종 구조를 한 파일로 보는 참고용이다 |
| `asset_schema_erdcloud_mysql.sql` | ERDCloud 가져오기용 | MySQL 문법. DB 생성에는 쓰지 않는다 ([ERD](https://app.notion.com/p/0f6b5085ff894ff79cdce72b84e74cc4) 2절) |

**핵심 제약 (v1에 포함, 26개)**

| 구분 | 제약 | 처음부터 두는 이유 |
|---|---|---|
| 서비스 로직이 기대는 키 | `ux_users_login_id`, `uq_stock_transactions_request_id`, `ux_stock_balances_key`, `uq_period_closings_period`, `ux_monthly_stock_snapshots_key` | 없으면 로그인 조회, 중복 요청 방지, 현재 재고 업서트, 마감 잠금이 동작하지 않는다 |
| 원장 보호 | 원장 수정·삭제 차단 트리거(함수 포함), `uq_ledger_entries_reversal_of_entry_id`, `ck_ledger_entries_3`·`_4` | 원장 추가 전용, 1회 취소, 수량 0 금지, 소유 구분 일관성 |
| 현재 재고 | `ck_stock_balances_3`·`_4` | 음수 재고 금지. 동시성 버그를 잡는 마지막 그물 |
| 수량 안전망 | 거래 품목·배정·납품·반품·대차·대차 정산·구성 묶음의 수량 CHECK 14개 | 수량 > 0, 기준일 이전 처리 ≥ 0, 기준일 이전 처리+처리+마감 ≤ 문서 수량, 소진·반품·정산 ≤ 원 수량 |

**적용 순서**

1. 개발·테스트 DB: v1 적용 → 서비스 개발·테스트 (2026-11-24부터 Flyway 마이그레이션으로 적용한다. v1 = Flyway V1~V5)
2. 서비스 테스트가 끝나면 v2 적용. ADD CONSTRAINT는 기존 데이터를 검사하므로, 막히면 에러의 제약 이름으로 서비스 버그나 잘못된 데이터를 찾는다. 파일 전체가 한 트랜잭션이라 중간 상태로 남지 않는다
3. 운영 DB: Flyway 마이그레이션으로 만든다(예전 계획은 운영 최종본 하나만 적용)

**관리 규칙**

- 세 파일은 같은 생성 스크립트에서 함께 만든다. 파일을 직접 고치지 않는다. 협의 결과로 코드 목록이 바뀌면 이 페이지 → 생성 스크립트 순서로 고친 뒤 다시 만든다. Flyway 마이그레이션을 더하면 생성 스크립트도 같이 고치고, v1 = Flyway인지 확인한다(`tools/ddl/verify.sh`, 2026-11-26).
- 만들 때마다 PostgreSQL 16(2026-11-24부터 18)에서 "v1 → v2 적용 DB"와 "운영 최종본 적용 DB"의 스키마·초기 데이터가 같은지 비교한다. 2026-10-30 기준 동일함을 확인했다. 기준일 이전 처리 수량·기준일 이전 납품 장비를 반영한 뒤 2026-11-02에 다시 확인했다 (테이블 46개, 외래 키 96개, 핵심 제약 25개, v2 제약 72개). 같은 날 옮길 기존 데이터가 없어 기존 데이터 ID 칸(legacy_id)을 products·partners·equipment·projects·trade_documents에서 뺐다 (컬럼 494개). 2026-11-03 대차 변경 이력을 일반형(loan_document_changes)으로 바꾼 뒤 다시 확인했다 (테이블 46개, 컬럼 496개, 외래 키 97개, 핵심 제약 25개, v2 제약 72개). 같은 날 제품 변경 이력(product_changes, #78)을 추가하고 다시 확인했다 (테이블 47개, 컬럼 504개, 외래 키 98개, 핵심 제약 25개, v2 제약 72개). 2026-11-09 초기 재고 단가(opening_costs, #81)를 추가하고 다시 확인했다 (테이블 48개, 컬럼 516개, 외래 키 100개, 핵심 제약 25개, v2 제약 74개, 보강 제안 11개). 2026-11-23 토큰 무효 기준 시각(users.tokens_valid_after)을 추가하고 다시 확인했다 (테이블 48개, 컬럼 517개, 외래 키 100개, 핵심 제약 25개, v2 제약 74개, 보강 제안 11개). 같은 날 API 설계에 필요한 테이블 6개(로그인 토큰, 중복 요청 키, 대차 정산 기록, 승인·확인 요청, 알림, 정합성 점검 결과)와 컬럼 3개(실사 담당자, 장비 이력의 이전·새 값)를 추가하고, 대차 품목의 정산 제품 칸을 정산 기록으로 옮긴 뒤 다시 확인했다 (테이블 55개, 컬럼 606개, 외래 키 105개, 핵심 제약 26개, v2 제약 107개, 보강 제안 11개). 같은 날 1단계 API를 쓰며 마스터 7개 테이블에 소프트 삭제([DEL])를 넣고 코드·번호 UNIQUE 6개를 삭제 제외 부분 유니크로 바꾼 뒤 다시 확인했다 (테이블 55개, 컬럼 645개, 외래 키 105개, 핵심 제약 26개, v2 제약 107개, 보강 제안 11개). 2026-11-24 PDF 읽기를 보류하고 증빙 첨부로 바꿔(#104) import_jobs와 trade_documents.source_file_id를 빼고 files를 첨부 테이블로 바꾼 뒤 다시 확인했다 (테이블 54개, 컬럼 639개, 외래 키 102개, 핵심 제약 26개, v2 제약 109개, 보강 제안 11개). 같은 날 대상 DB를 PostgreSQL 18로 올리고 id 기본값을 uuidv7()로 바꾼 뒤 18.7에서 다시 확인했다. 세 파일 스키마 동일, 점검 쿼리 C9–C15는 정상 데이터 0행·일부러 틀어 놓은 11가지 모두 감지. 2026-11-26 Flyway V2–V5(중복 요청 응답 json, 세션 로그인 테이블, 원래 통화 금액 소수 4자리, 역할·권한 체계)를 생성 스크립트에 반영해 다시 만들고 확인했다 (테이블 55개, 컬럼 627개, 외래 키 103개, 핵심 제약 26개 + 나중 마이그레이션 제약 4개, v2 제약 107개, 보강 제안 11개). v1 = Flyway V1–V5, v1 → v2 = 운영 최종본, 초기 데이터 모두 같음.
- 제약 이름은 세 파일에서 같다. 테스트·에러 코드 매핑에서 제약 이름을 그대로 쓸 수 있다.
- 개발이 시작되면 원본은 Git의 Flyway 마이그레이션으로 옮기고, 이 파일들은 참고용이 된다.

## 1. 공통 규칙

| 항목 | 규칙 |
|---|---|
| DB | PostgreSQL 18 (2026-11-24, 16에서 변경). 백엔드 모듈별로 스키마를 나눈다 (2절) |
| 기본 키 | `id uuid DEFAULT uuidv7()` (2026-11-24 고침. UUID 전환 때 남은 잘못된 표기). Item Code·시리얼·문서번호 같은 업무 키는 별도 UNIQUE 컬럼으로 둔다 |
| 이름 | snake_case, 테이블은 복수형, 외래 키는 `{대상}_id` |
| 날짜·시각 | 업무 날짜는 `date`, 기록 시각은 `timestamptz` (표시는 Asia/Seoul) |
| 수량 | `integer`. 단위는 제품의 unit을 따른다 |
| 금액 | 단가는 `numeric(19,4)`, 원래 통화로 넣는 금액·비용(`amount`)은 `numeric(20,4)`, 원화 환산(`amount_krw`)은 `numeric(18,2)` (2026-11-26 변경, COST-05: 소수 3자리 통화도 담도록. 통화마다 받는 자리 수는 `currencies.minor_unit`으로 서버가 검사). 모든 금액 행에 `currency`(통화, 기본 KRW), `exchange_rate`(기본 1), `amount_krw`(원화 환산)를 둔다. 현재는 원화만 쓰므로 기본값으로 채워지고 화면에서는 숨긴다. 마진·합계는 amount_krw 기준으로 계산한다. 금액은 cost 스키마에만 둔다 (권한 분리, COST-04) |
| 코드값 | 시스템 로직이 의존하는 값(처리 유형, 재고 상태 등)은 `varchar`와 CHECK 제약. 사용자가 늘릴 수 있는 분류(품목군)는 코드 테이블 |
| [AUD] 공통 감사 컬럼 | `created_at`, `created_by`, `updated_at`, `updated_by`, `version`(낙관적 잠금). 표에서는 [AUD]로 줄여 표기. 모든 id와 id를 가리키는 커럼(FK, created_by 등 \*_by, source_id·target_id·entity_id)은 uuid다. UUID v7을 앱이 만들고 DB 기본값은 uuidv7()(PostgreSQL 18 내장, 2026-11-24 gen_random_uuid()에서 변경). size_bytes만 bigint (2026-11-23 bigint IDENTITY에서 변경, ADR "모든 ID는 UUID") |
| [DEL] 소프트 삭제 | `deleted_at`, `deleted_by`. 사용자가 등록하는 마스터(제품·품목군·창고·위치·거래처·담당자·사용자)와 업무 문서에 둔다(2026-11-23 마스터로 확대). 원장·이력 테이블에는 두지 않는다. 코드·번호의 UNIQUE는 삭제된 행을 뺀 부분 유니크로 건다 |
| 원장 보호 | 애플리케이션 계정에는 `inventory.ledger_entries`의 UPDATE·DELETE 권한을 주지 않고, 트리거로도 차단한다 |
| 소유 키 | 재고 키는 `제품 × 위치 × 재고 상태 × 소유`. 소유는 `owner_type`(OWN/THIRD_PARTY) + `owner_partner_id`(타사일 때 필수) |
| 예외 | `auth.spring_session`·`auth.spring_session_attributes`는 Spring Session JDBC 공식 스키마를 그대로 쓴다(char(36) PK, 시각은 epoch 밀리초 bigint, 감사 컬럼 없음. 2026-11-25 `oauth2_authorization`에서 바꿈). 시스템이 쓰는 기록인 `common.idempotency_keys`, `admin.notifications`, `admin.integrity_check_results`에는 [AUD]를 두지 않는다 (2026-11-23) |

## 2. 스키마 구성

| 스키마 | 테이블 | 모듈 | 단계 |
|---|---|---|---|
| auth | users, permissions, roles, role_permissions, spring_session, spring_session_attributes | user | 1 |
| product | product_categories, products, product_changes, bundles, bundle_components | product | 1 |
| warehouse | warehouses, locations | warehouse | 1 |
| partner | partners, partner_roles, contacts | partner | 1 |
| inventory | stock_transactions, ledger_entries, stock_balances, period_closings, period_closing_events, monthly_stock_snapshots, stock_counts, stock_count_scopes, stock_count_lines, stock_count_serials | inventory | 2 |
| equipment | equipment, equipment_events, warranties, warranty_changes | equipment | 2 / 4 |
| project | projects, trade_documents, trade_lines, trade_document_changes | project | 3 |
| allocation | allocations, allocation_events | allocation | 3 |
| delivery | deliveries, delivery_lines, delivery_returns | delivery | 3 |
| loan | loan_documents, loan_lines, loan_settlements, loan_document_changes | loan | 3 |
| trash | trash_events | trash | 3 |
| cost | currencies, line_prices, extra_costs, loan_fees, opening_costs, cost_changes | cost | 4 |
| importing | files (import_jobs는 PDF 읽기와 함께 보류, #104) | importing | 5 |
| common | idempotency_keys | common | 2 |
| admin | review_requests, notifications, integrity_check_results | admin | 2 |

## 3. 마스터 테이블

### 3.1 auth.users — 사용자

| 컬럼 | 타입 | NULL | 제약 | 설명 |
|---|---|---|---|---|
| id | uuid | N | PK |  |
| login_id | varchar(50) | N | UNIQUE (삭제된 것 제외) | 로그인 ID. 바꿀 수 있다(겹침 검사) |
| name | varchar(100) | N |  | 이름 |
| email | varchar(200) | Y |  |  |
| password_hash | varchar(200) | N |  | 평문 저장 금지 |
| is_active | boolean | N | 기본 true | 퇴사·비활성 |
| last_login_at | timestamptz | Y |  |  |
| role_id | uuid | N | FK roles | 역할 하나 (2026-11-26 추가, #106). 바꾸면 tokens_valid_after를 기록한다 |
| must_change_password | boolean | N | 기본 false | 다음 로그인 때 비밀번호 변경 필요. `USER_MANAGE` 권한자가 계정을 만들거나 비밀번호를 초기화하면 true, 본인이 바꾸면 false. true인 동안은 내 정보·비밀번호 변경·로그아웃만 가능 (2026-11-23 추가, #100) |
| tokens_valid_after | timestamptz | Y |  | 세션 무효 기준 시각. 역할·사용 여부·로그인 ID·비밀번호를 바꾸면 지금으로 기록한다. 이보다 먼저 로그인한 세션은 끊는다. 이름은 토큰 방식 때 지은 것을 그대로 둔다 (2026-11-23, 2026-11-25 세션 방식으로 바꿈, API 명세서 1.3절) |
| [DEL] |  |  |  | 소프트 삭제 (2026-11-23 추가, API 명세서 1.9절) |
| [AUD] |  |  |  |  |

### 3.2 auth.permissions / roles / role_permissions — 역할과 권한 (2026-11-26 바꿈, #106)

권한 13개를 독립적으로 두고, 역할은 권한을 고른 묶음이며, 계정은 역할 하나를 갖는다([권한 매트릭스](https://app.notion.com/p/40ea7b147db34b08b8bdfff1001cc500) 1절). 예전 `user_roles`·`user_permissions`는 없앤다.

| 테이블 | 컬럼 | 설명 |
|---|---|---|
| permissions | code varchar(30) PK, name varchar(50), description varchar(200), sort_order smallint | 권한 13개. 마이그레이션으로만 넣고 화면에서 바꾸지 않는다(코드가 권한을 검사하므로). 코드의 권한 목록과 같은지 테스트한다 |
| roles | id uuid PK, code varchar(30), name varchar(50), description varchar(200) Y, [AUD], [DEL], version | 역할. code는 만든 뒤 바꾸지 않고 대문자·숫자·밑줄(`^[A-Z][A-Z0-9_]*$`). code·name은 삭제된 것을 빼고 겹치지 않는다(`ux_roles_code`, `ux_roles_name`, 부분 유니크). 기본 역할 6개를 마이그레이션으로 넣는다: ADMIN 관리자, OPERATOR_BASIC 일반 운영자, OPERATOR_COST_VIEW 영업 운영자, OPERATOR_COST_EDIT 정산 운영자, USER_BASIC 일반 사용자, USER_COST_VIEW 회계 사용자. 코드 형식은 `ck_roles_code`로 DB에서도 막는다. 기본 역할은 만든 사람이 없어 `created_by`가 NULL이다(roles만 created_by NULL 허용) |
| role_permissions | role_id FK roles, permission_code FK permissions (PK 복합) | 역할에 넣은 권한. ADMIN은 13개 전부이고 바꿀 수 없다(서비스에서 막음). COST_EDIT이 있으면 COST_VIEW도 있다(서비스에서 검사, INV-88) |

- users에 `role_id uuid NOT NULL FK roles`를 더한다(3.1). 인덱스 `ix_users_role_id`(역할 삭제 전 사용 중인지 확인, R4).
- 역할 삭제는 소프트 삭제다(#102). 그 역할인 계정(삭제된 계정 제외)이 있으면 지울 수 없다.
- 관리자 역할 판별은 code `ADMIN`으로 한다(따로 표시 컬럼을 두지 않는다. 잠그는 역할이 하나뿐이다).
- V5 마이그레이션(2026-11-26)이 예전 계정을 옮긴다: 관리자 → ADMIN, 입력자 → 금액 권한에 따라 OPERATOR_BASIC·OPERATOR_COST_VIEW·OPERATOR_COST_EDIT, 조회자 → USER_BASIC 또는 금액 권한이 있으면 USER_COST_VIEW, 역할 없음 → USER_BASIC. 역할이 여럿이면 가장 큰 것.

### 3.2.1 auth.spring_session / spring_session_attributes — 로그인 세션 (2026-11-25, `oauth2_authorization`을 바꿈)

- Spring Session JDBC가 로그인 세션을 저장한다. 서버를 다시 켜도 로그인이 유지된다. 마지막 요청 뒤 8시간이 지나면 만료되고, Spring Session이 1분마다 만료된 행을 지운다 ([API 명세서](https://app.notion.com/p/408b82ca31e580d19b7ee382dacd572b) 1.3절, ADR "인증 방식: 세션 로그인").
- 공통 규칙 예외: Spring 공식 스키마 그대로다(마이그레이션 V3). 이름만 소문자·auth 스키마·우리 제약 이름 규칙으로 바꿨다. 컬럼 이름이나 타입을 바꾸면 Spring이 읽지 못한다.
- principal_name은 users.id(문자열)다. 외래 키는 걸지 않는다(Spring이 관리). attributes에는 사용자 ID와 로그인 시각만 직렬화해 저장한다. 권한은 요청마다 users·role_permissions에서 읽는다 (2026-11-25, 2026-11-26 역할·권한 체계 변경).
- 2026-11-25: 토큰 방식(`oauth2_authorization`)을 세션 방식으로 바꾸면서 V3 마이그레이션으로 지웠다.

| 테이블 | 컬럼 |
|---|---|
| spring_session | primary_id char(36) PK, session_id char(36) UNIQUE(쿠키 값, 로그인할 때 바뀜), creation_time, last_access_time, max_inactive_interval(초), expiry_time, principal_name Y. 시각은 epoch 밀리초 bigint |
| spring_session_attributes | session_primary_id char(36) FK(ON DELETE CASCADE), attribute_name varchar(200), attribute_bytes bytea. PK(session_primary_id, attribute_name) |

### 3.3 product.product_categories — 품목군

| 컬럼 | 타입 | NULL | 제약 | 설명 |
|---|---|---|---|---|
| id | uuid | N | PK |  |
| code | varchar(30) | N | UNIQUE (삭제된 것 제외) | UPS, RPDU, RACK, KVM, MONITORING_SENSOR, TH_SENSOR, COOLING (PROD-03) |
| name | varchar(100) | N |  | 표시명 |
| sort_order | integer | N |  | 홈·필터 표시 순서 |
| [DEL] |  |  |  | 소프트 삭제 (2026-11-23 추가, API 명세서 1.9절). 코드도 바꿀 수 있다(겹침 검사) |
| is_active | boolean | N |  |  |

### 3.4 product.products — 제품

| 컬럼 | 타입 | NULL | 제약 | 설명 |
|---|---|---|---|---|
| id | uuid | N | PK | 기존 설계의 UUID를 uuid로 변경 |
| item_code | varchar(50) | N | UNIQUE (삭제된 것 제외) | 문자열 저장, 앞자리 0 보존 (PROD-01) |
| product_name | varchar(200) | N |  |  |
| model_name | varchar(100) | Y |  |  |
| category_id | uuid | N | FK product_categories | 기존 category·product_group 정리 |
| manufacturer | varchar(100) | Y |  |  |
| component_role | varchar(100) | Y |  | 구성품 역할 |
| specification | text | Y |  | 규격·설명 |
| unit | varchar(20) | N | 기본 EA |  |
| serial_managed | boolean | N | 기본 false | 시리얼 관리 여부 (PROD-05). 이력이 생긴 뒤에는 변경 불가 |
| is_active | boolean | N | 기본 true | 이력 있는 제품은 삭제 대신 비활성 (PROD-04). 사용 중지·다시 사용은 `MASTER_MANAGE`, 재고·미처리 문서 품목·활성 배정·대차 잔량이 남으면 차단 (트랜잭션 검증, #78) |
| [DEL] |  |  |  | 소프트 삭제 (2026-11-23 추가). 이력 없는 제품만 삭제 (#78, API 명세서 1.9절) |
| note | text | Y |  |  |
| [AUD] |  |  |  |  |

### 3.4.1 product.product_changes — 제품 변경 이력 (2026-11-03 추가)

| 컬럼 | 설명 |
|---|---|
| id, product_id FK products, field_name varchar(50), old_value text Y, new_value text Y, reason Y, changed_by, changed_at | 제품 변경 이력. trade_document_changes·loan_document_changes와 같은 일반형. 이력 있는 제품의 Item Code 변경(`RECORD_CORRECT`, 사유 필수), 사용 중지·다시 사용을 항목마다 한 줄로 남긴다 (확정 사항 #78, ISS-14). 지난 원장의 제품 스냅샷은 바꾸지 않는다 |

### 3.5 product.bundles / bundle_components — 구성 묶음

| 테이블 | 컬럼 | 설명 |
|---|---|---|
| bundles | id, bundle_code UNIQUE(삭제된 것 제외, ux_bundles_bundle_code), bundle_name, is_active, note, [AUD], [DEL] (2026-11-23 추가) | GXE3 같은 구성 묶음. 묶음 자체의 재고는 두지 않는다 (KIT-01) |
| bundle_components | id, bundle_id FK, product_id FK, quantity_per_set integer > 0, UNIQUE(bundle_id, product_id) | 묶음 1세트당 구성품 수량. 구성비 확정 전까지 비워 둘 수 있음 (ISS-6) |

### 3.6 warehouse.warehouses — 창고

| 컬럼 | 타입 | NULL | 제약 | 설명 |
|---|---|---|---|---|
| id | uuid | N | PK |  |
| warehouse_code | varchar(30) | N | UNIQUE (삭제된 것 제외) |  |
| warehouse_name | varchar(100) | N |  | 예: 유니포인트 창고 |
| [DEL] |  |  |  | 소프트 삭제 (2026-11-23 추가). 위치가 없을 때만 삭제 |
| address | varchar(300) | Y |  |  |
| is_active | boolean | N |  |  |
| note | text | Y |  |  |
| [AUD] |  |  |  |  |

### 3.7 warehouse.locations — 위치 (기존 warehouse_locations)

자사 창고 안의 보관 위치뿐 아니라 외부 위치(수리처·대여처·고객사 현장)도 같은 테이블에 둔다. 외부 위치는 상대 업체별로 하나씩 만든다.

| 컬럼 | 타입 | NULL | 제약 | 설명 |
|---|---|---|---|---|
| id | uuid | N | PK |  |
| location_code | varchar(30) | N | UNIQUE (삭제된 것 제외) |  |
| location_name | varchar(100) | N |  | 예: 본사 지하 4층 |
| [DEL] |  |  |  | 소프트 삭제 (2026-11-23 추가). 이력 없는 위치만 삭제. 재고가 남아 있어도 사용 중지는 가능 |
| location_type | varchar(20) | N | CHECK IN ('INTERNAL','REPAIR','LOAN_OUT','CUSTOMER_SITE') | 자사 창고 / 수리처 / 대여처 / 고객사 현장 |
| warehouse_id | uuid | Y | FK warehouses | INTERNAL일 때만 필수 (CHECK) |
| partner_id | uuid | Y | FK partners | 외부 위치의 상대 업체. 외부 위치일 때 필수 (CHECK) |
| zone, rack, shelf | varchar(30) | Y |  |  |
| is_active | boolean | N |  |  |
| note | text | Y |  |  |
| [AUD] |  |  |  |  |

### 3.8 partner 스키마 — partners / partner_roles / contacts (거래처)

| 테이블 | 컬럼 | 설명 |
|---|---|---|
| partners | id, partner_name varchar(200) N, business_reg_no varchar(20) Y (값이 있으면 UNIQUE, 삭제된 것 제외), address, phone, is_active, note, [AUD], [DEL](2026-11-23) | 고객사·공급사·차입처·대여처 공통 (PARTY-01~02) |
| partner_roles | partner_id, role CHECK IN ('CUSTOMER','SUPPLIER') (PK 복합) | 한 거래처가 여러 역할 가능. 매입·매출·선발주 구분은 거래 문서에 둔다 |
| contacts | id, partner_id FK, name, department, position, phone, email, is_primary(주 담당자는 거래처당 한 명, 트랜잭션 검증), [AUD], [DEL](2026-11-23) | 담당자 (소속·직위·번호·이메일) |

## 4. 재고 원장 (inventory)

### 4.1 inventory.stock_transactions — 처리 묶음 (헤더)

한 번의 업무 처리(일괄 입출고, 이동, 교체 등)를 하나의 묶음으로 확정한다. 묶음 안의 원장 행은 한 트랜잭션에서 모두 반영되거나 모두 취소된다 (NFR-02).

| 컬럼 | 타입 | NULL | 제약 | 설명 |
|---|---|---|---|---|
| id | uuid | N | PK |  |
| transaction_no | varchar(30) | N | UNIQUE | 화면 표시용 처리 번호 |
| transaction_type | varchar(30) | N | CHECK (4.6 목록) | 처리 유형 |
| business_date | date | N |  | 업무 날짜. 미래 날짜 금지, 마감 기간 금지 |
| status | varchar(10) | N | CHECK IN ('DRAFT','POSTED') | 임시 / 확정 |
| request_id | varchar(64) | N | UNIQUE | 중복 요청 방지 키 (NFR-04) |
| related_transaction_id | uuid | Y | FK 자기 자신 | 취소·정정 대상 원본 묶음 |
| source_type | varchar(30) | Y |  | 요청한 업무 출처. TRADE_LINE, DELIVERY, LOAN, STOCK_COUNT 등. 재고 조정은 STOCK_COUNT(실사 건) 또는 STOCK_TRANSACTION(마감된 달의 원래 처리 묶음) 중 하나 (확정 사항 #63). inventory는 출처 모듈을 직접 참조하지 않는다 |
| source_id | uuid | Y |  | 출처 행 ID |
| counterparty_partner_id | uuid | Y | FK partners | 기존 counterparty(텍스트)를 거래처 참조로 변경 |
| reason_code | varchar(30) | Y |  | OVER_RECEIPT, MIS_SHIPMENT, FREE_REPLACEMENT, SAMPLE, COUNT_DIFF, DISPOSAL 등. 해당 유형에서 필수 |
| reason | text | Y |  | 상세 사유 |
| reference_no | varchar(100) | Y |  | 외부 문서번호 |
| approved_by / approved_at | uuid / timestamptz | Y |  | 승인(`APPROVE`)이 필요한 유형(폐기, 대여 출고, 실사 조정, 마감 예외) |
| note | text | Y |  | 예: 수령 거부 메모 |
| created_at / created_by | timestamptz / uuid | N |  |  |
| posted_at / posted_by | timestamptz / uuid | Y |  | 확정 시각·확정자 |

### 4.2 inventory.ledger_entries — 원장 (기존 low_data)

제품·위치·상태·소유별 수량 증감. **INSERT만 허용**하고 수정·삭제하지 않는다 (HIST-02).

| 컬럼 | 타입 | NULL | 제약 | 설명 |
|---|---|---|---|---|
| id | uuid | N | PK |  |
| transaction_id | uuid | N | FK stock_transactions |  |
| line_no | integer | N | UNIQUE(transaction_id, line_no) |  |
| product_id | uuid | N | FK products |  |
| location_id | uuid | N | FK locations |  |
| stock_condition | varchar(20) | N | CHECK IN ('AVAILABLE','INSPECTION','DEFECTIVE','IN_REPAIR') | 재고 상태 4종으로 확정 |
| owner_type | varchar(20) | N | CHECK IN ('OWN','THIRD_PARTY') | 자사 / 타사(차입) |
| owner_partner_id | uuid | Y | FK partners | THIRD_PARTY일 때 필수 (CHECK) |
| quantity_delta | integer | N | CHECK \<> 0 | 입고 +, 출고 − |
| business_date | date | N |  | 헤더 값 복사. 과거 날짜 검증용 인덱스 |
| equipment_id | uuid | Y | FK equipment | 시리얼 장비 처리 시 필수. 기존 serial_no 대체 |
| pair_id | uuid | Y |  | 이동·상태 변경·소유 전환처럼 한 쌍인 행 묶음 (기존 movement_pair_id) |
| reversal_of_entry_id | uuid | Y | FK 자기 자신, UNIQUE | 한 행은 한 번만 취소. 취소 행 자체는 취소 불가 (트랜잭션 검증) |
| trade_line_id | uuid | Y |  | 입고·출고가 연결된 거래 품목 (조회용 참조). 발주 처리 수량에는 입고·공급사 반품·오류 조정(과 그 취소·정정) 행만 들어간다. 발주 외 입고와 그 공급사 반품 행에는 적지 않고, 원 발주 참조는 처리 묶음의 source로 남긴다 (#82) |
| lot_no | varchar(50) | Y |  |  |
| item_code_snapshot | varchar(50) | N |  | 처리 당시 Item Code |
| product_name_snapshot | varchar(200) | N |  | 처리 당시 제품명 |
| note | text | Y |  |  |
| created_at / created_by | timestamptz / uuid | N |  | 수정 컬럼 없음 |

인덱스: (product_id, location_id, stock_condition, owner_type, owner_partner_id, business_date) — 과거 날짜 입력 시 날짜별 재고 재검증에 사용.

### 4.3 inventory.stock_balances — 현재 재고 (기존 v_current_stock 대체)

View로는 잠글 행이 없어 동시 출고를 막을 수 없으므로, 현재 수량을 테이블로 두고 원장과 같은 트랜잭션에서 갱신한다. 출고·배정 시 이 행을 `SELECT … FOR UPDATE`로 잠근다 (NFR-03). 원장 합계와의 일치 여부는 대조 쿼리로 주기 점검한다.

| 컬럼 | 타입 | NULL | 제약 | 설명 |
|---|---|---|---|---|
| id | uuid | N | PK |  |
| product_id | uuid | N | FK products |  |
| location_id | uuid | N | FK locations |  |
| stock_condition | varchar(20) | N | CHECK (4종) |  |
| owner_type | varchar(20) | N | CHECK |  |
| owner_partner_id | uuid | Y | FK partners |  |
| quantity | integer | N | CHECK >= 0 | 음수 재고 DB 차단 |
| updated_at | timestamptz | N |  |  |

UNIQUE NULLS NOT DISTINCT (product_id, location_id, stock_condition, owner_type, owner_partner_id).

### 4.4 월 마감 — period_closings / period_closing_events / monthly_stock_snapshots

| 테이블 | 컬럼 | 설명 |
|---|---|---|
| period_closings | id, period char(7) UNIQUE ('YYYY-MM'), status CHECK IN ('OPEN','CLOSED'), closed_at, closed_by, snapshot_version integer | 월별 마감 상태. CLOSED 기간의 업무 날짜로는 처리 불가 |
| period_closing_events | id, period, action CHECK IN ('CLOSE','REOPEN'), reason, acted_by, acted_at | 마감·해제 이력. 해제는 `CLOSING`, 사유 필수 |
| monthly_stock_snapshots | id, period, snapshot_version, product_id, location_id, stock_condition, owner_type, owner_partner_id, quantity | 마감 시점 월말 재고. 재마감 시 버전 증가, 이전 버전 보관 |

### 4.5 재고 실사 — stock_counts / stock_count_scopes / stock_count_lines / stock_count_serials

| 테이블 | 컬럼 | 설명 |
|---|---|---|
| stock_counts | id, count_no UNIQUE, scope_type CHECK IN ('LOCATION','PRODUCT'), base_date date, assignee_id (담당자, 준비 때 지정, 2026-11-23 추가), status CHECK IN ('PREPARED','IN_PROGRESS','REVIEW','APPROVED','CANCELLED'), started_at, approved_by, approved_at, adjustment_transaction_id FK stock_transactions, note, [AUD] | 실사 건. IN_PROGRESS 동안 범위 잠금 |
| stock_count_scopes | id, count_id FK, location_id Y, product_id Y | 잠금 범위. 입출고·배정 처리 시 진행 중 실사 범위와 겹치는지 검사 |
| stock_count_lines | id, count_id FK, product_id, location_id, stock_condition, owner_type, owner_partner_id, book_quantity (시작 시점 장부), counted_quantity Y, recounted boolean, note | 품목별 장부·실물 수량. 차이 = counted − book |
| stock_count_serials | id, count_id FK, line_id FK, serial_no, equipment_id Y, result CHECK IN ('MATCHED','MISSING','UNEXPECTED') | 시리얼 대조 결과. MISSING → 분실, UNEXPECTED → 신규 등록 |

### 4.6 처리 유형 코드 (transaction_type)

| 구분 | 코드 |
|---|---|
| 정방향 | OPENING, RECEIPT, ISSUE, TRANSFER, ADJUSTMENT |
| 정방향 (추가) | UNPLANNED_RECEIPT |
| 역방향 | CUSTOMER_RETURN, INSPECTION_RESULT, SUPPLIER_RETURN, REPAIR_OUT, REPAIR_IN, EXCHANGE, DISPOSAL |
| 대차 | LOAN_IN_RECEIPT, LOAN_IN_REPAY, LOAN_IN_RETURN, TEMP_INSTALL, LOAN_OUT_ISSUE, LOAN_OUT_RETURN, LOAN_OUT_SETTLE, OWNERSHIP_TRANSFER |
| 보정 | REVERSAL, CORRECTION |

## 5. 업무 테이블

### 5.1 equipment 스키마 — equipment (개별 장비, 시리얼)

| 컬럼 | 타입 | NULL | 제약 | 설명 |
|---|---|---|---|---|
| id | uuid | N | PK |  |
| product_id | uuid | N | FK products | serial_managed = true인 제품만 |
| serial_no | varchar(100) | Y | UNIQUE(product_id, serial_no) WHERE serial_no IS NOT NULL | 미확인이면 NULL. 유니크 범위는 ISS-2 확정 후 조정 |
| serial_status | varchar(20) | N | CHECK IN ('CONFIRMED','UNKNOWN') | 시리얼 미확인 구분. 처음 등록(MIG-03)과 새 입고(확정 사항 #60) 모두 |
| status | varchar(30) | N | CHECK (아래 상태 목록) | 현재 상태 |
| current_location_id | uuid | Y | FK locations | 납품 완료 후에는 NULL, 납품처로 관리 |
| owner_type / owner_partner_id | varchar(20) / uuid | N / Y |  | 자사 / 타사(차입 장비) |
| project_id | uuid | Y |  | 배정·납품된 프로젝트 |
| delivered_partner_id | uuid | Y | FK partners | 납품처 고객사 |
| replaced_by_equipment_id | uuid | Y | FK 자기 자신 | 교체·수리 시 다른 시리얼로 돌아온 경우 새 장비 연결 |
| origin_type | varchar(30) | N | 기본 'LEDGER', CHECK IN ('LEDGER','PRE_CUTOVER_DELIVERY') | 생성 경로. LEDGER = 입고·초기 재고 등 원장 처리로 생성. PRE_CUTOVER_DELIVERY = 기준일 이전 납품 장비로 등록(원장 없이 납품 완료 상태로 생성, 확정 사항 #50) |
| last_event_date | date | N |  | 마지막 처리 업무 날짜. 이보다 앞선 날짜 처리 금지 |
| [AUD] |  |  |  |  |

상태 목록: IN_STOCK(정상 재고), INSPECTION(검수 대기), DEFECTIVE(불량), IN_REPAIR(수리 중), ISSUED(출고), DELIVERED(납품 완료), TEMP_INSTALLED(임시 설치), LOANED_OUT(대여 중), LOST(분실), REPLACED(교체됨), DISPOSED(폐기), RETURNED_TO_SUPPLIER(공급사 반품), TRANSFERRED_OUT(타사로 이전·상환됨), RECEIPT_CANCELLED(입고 취소). 전이 규칙은 재고 원장 처리 규칙 6절. 기준일 이전 납품 장비는 처음부터 DELIVERED로 생성한다.

### 5.2 equipment 스키마 — equipment_events / warranties / warranty_changes

| 테이블 | 컬럼 | 설명 |
|---|---|---|
| equipment_events | id, equipment_id FK, event_type, business_date, from_status, to_status, from_location_id, to_location_id, old_value Y, new_value Y (2026-11-23 추가), ledger_entry_id Y, source_type, source_id, note, created_at, created_by | 장비 이동·상태 이력 (ASSET-02). 원장 없는 이력(현장 수리 ONSITE_REPAIR, 기준일 이전 납품 등록 PRE_CUTOVER_DELIVERY 등)도 기록. 시리얼 수정·확인(SERIAL_CORRECTED·SERIAL_CONFIRMED)은 old_value·new_value에 이전·이후 번호를, 비고에 사유를 남긴다 (확정 사항 #59·#60, 2026-11-23 비고에서 옮김). 기준일 이전 납품 등록의 business_date는 납품일 |
| warranties | id, equipment_id FK UNIQUE, status CHECK IN ('CONFIRMED','UNKNOWN'), start_date Y, end_date Y, basis Y CHECK IN ('DELIVERY','MANUFACTURER','PURCHASE','MANUAL') (2026-11-23, #95), inherited_from_equipment_id Y, note, [AUD]. CHECK (end_date >= start_date) | 보증 기간 (ASSET-03). 교체 시 원 장비 잔여 기간 승계. 원 장비가 UNKNOWN이면 승계 장비도 UNKNOWN으로 시작 (#75). 시작 기준(basis)은 ISS-3 |
| warranty_changes | id, warranty_id FK, old_start_date, old_end_date, new_start_date, new_end_date, reason, changed_by, changed_at | 보증 변경 이력 (ASSET-04). 미확인을 처음 채우면 이전 값이 비고 사유 생략 가능, 이미 넣은 날짜를 바꾸면 reason 필수 (트랜잭션 검증, #75) |

### 5.3 project.projects — 프로젝트

| 컬럼 | 타입 | NULL | 제약 | 설명 |
|---|---|---|---|---|
| id | uuid | N | PK |  |
| project_code | varchar(30) | N | UNIQUE | 자동 채번. 이름이 같은 프로젝트를 구분 (3.1절, ISS-8). 스탁 상시 프로젝트는 예약 코드 STOCK (확정 사항 #65) |
| project_name | varchar(200) | N |  | UNIQUE 아님 |
| customer_partner_id | uuid | Y | FK partners | 주 고객사 |
| status | varchar(20) | N | CHECK IN ('ACTIVE','COMPLETED','CANCELLED') |  |
| note | text | Y |  |  |
| [AUD], [DEL] |  |  |  |  |

### 5.4 project 스키마 — trade_documents (거래 문서: 발주서·매출·선발주)

| 컬럼 | 타입 | NULL | 제약 | 설명 |
|---|---|---|---|---|
| id | uuid | N | PK |  |
| project_id | uuid | N | FK projects | 한 프로젝트에 여러 문서 (PRJ-01) |
| trade_type | varchar(20) | N | CHECK IN ('PURCHASE','SALES','PRE_ORDER') | 사용자가 직접 선택. 자동 변경 없음 (PRJ-02) |
| partner_id | uuid | N | FK partners | 공급사 또는 고객사 |
| document_no | varchar(50) | Y | UNIQUE(partner_id, document_no) WHERE 삭제되지 않음 | 거래처 문서번호. 중복 기준은 ISS-9 |
| document_date | date | N |  | 발주일·매출일 |
| status | varchar(20) | N | CHECK IN ('DRAFT','CONFIRMED','COMPLETED','CANCELLED') | 수정 규칙은 재고 원장 처리 규칙 11절 |
| copied_from_document_id | uuid | Y | FK 자기 자신 | 매입→매출 복사 출처. 참조만, 이후 독립 (PRJ-04) |
| note | text | Y |  |  |
| [AUD], [DEL] |  |  |  |  |

### 5.5 project 스키마 — trade_lines (거래 품목)

| 컬럼 | 타입 | NULL | 제약 | 설명 |
|---|---|---|---|---|
| id | uuid | N | PK |  |
| document_id | uuid | N | FK trade_documents |  |
| line_no | integer | N | UNIQUE(document_id, line_no) |  |
| product_id | uuid | N | FK products | 처리 수량이 0일 때만 변경 가능 |
| quantity | integer | N | CHECK > 0 | 문서 수량 |
| opening_fulfilled_quantity | integer | N | 기본 0, CHECK >= 0 | 기준일 이전 처리 수량. 기준일 전에 이미 입고·직납(매입) 또는 납품(매출)된 수량. `STOCK_ADJUST`만, 첫 월 마감 전까지 입력·변경 (확정 사항 #48·#49) |
| fulfilled_quantity | integer | N | 기본 0 | 처리된 수량. 매입: 입고+직납, 매출: 유효 납품(납품−반품). 원장·납품과 같은 트랜잭션에서 갱신 |
| closed_quantity | integer | N | 기본 0 | 잔량 마감으로 종결한 수량 |
| closed_reason / closed_by / closed_at | text / uuid / timestamptz | Y |  | 잔량 마감 정보 (`CLOSING`) |
| route | varchar(20) | N | CHECK IN ('WAREHOUSE','DIRECT') | 창고 경유 / 현장 직납 |
| note | text | Y |  |  |
| [AUD] |  |  |  |  |

CHECK (opening_fulfilled_quantity + fulfilled_quantity + closed_quantity \<= quantity). 잔량 = quantity − opening_fulfilled_quantity − fulfilled_quantity − closed_quantity. 수량 감소는 처리 수량(기준일 이전 처리 포함)·배정 수량 이상으로만 허용 (트랜잭션 검증). 기준일 이전 처리 수량이 0보다 크면 일부 처리된 문서로 보고 문서 취소·품목 변경·줄 삭제를 막는다. fulfilled_quantity는 저장해 두는 값이다: 매입·선발주 = 입고·공급사 반품·오류 조정(그 취소·정정 포함)의 원장 수량 + 직납 수량, 매출 = 납품 − 반품, 대차 전환 문서 = 전환 정산 수량. 매일 점검 C9로 확인한다 (#82, INV-75).

### 5.6 project 스키마 — trade_document_changes (문서 변경 이력)

| 컬럼 | 설명 |
|---|---|
| id, document_id, line_id Y, field_name, old_value text, new_value text, reason Y, changed_by, changed_at | 확정 문서의 모든 수정 기록 (누가·언제·무엇을·이전 값→새 값). 대체품 수락 시 품목 변경, 발주 증액도 여기 남음 |

### 5.7 allocation.allocations / allocation_events — 배정

| 컬럼 | 타입 | NULL | 제약 | 설명 |
|---|---|---|---|---|
| id | uuid | N | PK |  |
| product_id | uuid | N | FK products |  |
| quantity | integer | N | CHECK > 0 | 배정 수량 |
| consumed_quantity | integer | N | 기본 0 | 출고·상환으로 소진된 수량 |
| target_type | varchar(20) | N | CHECK IN ('PROJECT','LOAN_REPAY') | 프로젝트 / 차입 상환 |
| project_id | uuid | Y |  | target_type = PROJECT일 때 필수 |
| loan_document_id | uuid | Y |  | target_type = LOAN_REPAY일 때 필수 |
| source_type | varchar(20) | N | CHECK IN ('STOCK','RECEIVED','PLANNED') | 보유 재고 배정 / 검수 대기 배정(입고 시 자동 전환, 출고 불가, #88·INV-81, 2026-11-23 추가) / 발주 예정 물량 배정 (ALLOC-04) |
| source_trade_line_id | uuid | Y | FK trade_lines | PLANNED일 때 필수 (발주 품목) |
| owner_type / owner_partner_id | varchar(20) / uuid | Y |  | STOCK 배정의 소유 구분. 타사 소유 재고도 배정 가능 |
| equipment_id | uuid | Y | FK equipment | 시리얼 장비 단위 배정 (ALLOC-03) |
| status | varchar(20) | N | CHECK IN ('ACTIVE','RELEASED','CONSUMED') |  |
| note, [AUD] |  |  |  |  |

"배정 합계 ≤ 배정 가능 수량(정상 상태)"은 여러 행에 걸친 조건이라 CHECK로 걸 수 없다. 배정 시 해당 stock_balances 행(또는 발주 품목 행)을 잠그고 트랜잭션에서 검증한다 (ALLOC-02). allocation_events에는 배정·변경·해제·소진·전환(CONVERT: 예정 → 검수 대기 → 보유, 2026-11-23 추가) 이력(id, allocation_id, action, quantity, reason, acted_by, acted_at)을 남긴다.

### 5.8 delivery.deliveries / delivery_lines / delivery_returns — 납품

| 테이블 | 컬럼 | 설명 |
|---|---|---|
| deliveries | id, delivery_no UNIQUE, project_id FK, sales_document_id Y, customer_partner_id FK, delivery_date date, place varchar(300), route CHECK IN ('WAREHOUSE','DIRECT'), bundle_id Y, bundle_set_quantity Y (세트 수. 묶음 납품이면 필수 > 0, 아니면 빈칸, #90, 2026-11-23 추가), status CHECK IN ('DRAFT','POSTED','CANCELLED'), transaction_id Y (창고 출고 묶음), note, [AUD] | 납품 회차 (DEL-01~04). 직납은 transaction_id 없음 |
| delivery_lines | id, delivery_id FK, line_no, product_id, quantity CHECK > 0, sales_line_id Y, purchase_line_id Y (직납 시 발주 품목), loan_line_id FK Y (차입 직납 시 대차 품목, #89, 2026-11-23 추가), equipment_id Y, returned_quantity 기본 0, note. CHECK (returned_quantity \<= quantity) | 회차별 품목. 직납은 purchase_line_id로 발주 잔량 차감 |
| delivery_returns | id, delivery_line_id FK Y, equipment_id FK Y, quantity, return_date, transaction_id (CUSTOMER_RETURN), reason, [AUD]. CHECK (delivery_line_id IS NOT NULL OR (equipment_id IS NOT NULL AND quantity = 1)) | 고객 반품. 유효 납품 = 납품 − 반품. 기준일 이전 납품 장비는 납품 품목 대신 equipment_id로 연결 (확정 사항 #52) |

창고 출고와 납품 완료를 하나의 사건으로 볼지는 ISS-7 미결. 현재 구조는 deliveries.transaction_id로 출고 묶음을 연결해 두 경우 모두 수용한다.

### 5.9 loan 스키마 — loan_documents / loan_lines / loan_settlements / loan_document_changes (차입·대여)

| 컬럼 (loan_documents) | 타입 | NULL | 제약 | 설명 |
|---|---|---|---|---|
| id | uuid | N | PK |  |
| loan_no | varchar(30) | N | UNIQUE |  |
| direction | varchar(10) | N | CHECK IN ('IN','OUT') | 차입 / 대여 |
| partner_id | uuid | N | FK partners | 차입처·대여처 |
| project_id | uuid | Y | FK projects | 차입하게 된 프로젝트 (참조용, 실제 사용 프로젝트는 출고 기록으로 연결) |
| settlement_method | varchar(20) | N | CHECK IN ('IN_KIND','CONVERT','RETURN_ORIGINAL') | ① 현물 / ② 거래 전환 / ③ 원물 반환. 정산 전까지 `RECORD_CORRECT` 권한자가 변경 가능 |
| due_date | date | Y |  | 상환·회수 기한. 지나면 경고 |
| status | varchar(20) | N | CHECK IN ('OPEN','SETTLED','CANCELLED') |  |
| converted_trade_document_id | uuid | Y | FK trade_documents | ② 거래 전환 시 생성한 매입·매출 문서 |
| approved_by / approved_at | uuid / timestamptz | Y |  | 대여 출고 승인(`APPROVE`) |
| note, [AUD], [DEL] |  |  |  |  |

| 테이블 | 컬럼 | 설명 |
|---|---|---|
| loan_lines | id, loan_id FK, line_no, product_id, quantity CHECK > 0, moved_quantity 기본 0 (받은(차입)·내보낸(대여) 수량, CHECK 0 ≤ moved ≤ quantity, #89, 2026-11-23 추가), settled_quantity 기본 0, equipment_id Y, note. CHECK (settled_quantity \<= quantity) | 차입 잔량·대여 잔량 = quantity − settled_quantity. settled_quantity = 확정된 정산 기록 합계(점검 C13). 정산한 실제 제품 칸(settled_product_id)은 2026-11-23 loan_settlements로 옮김 |
| loan_settlements (2026-11-23 추가) | id, loan_line_id FK, settled_date, method CHECK IN ('IN_KIND','CONVERT','RETURN_ORIGINAL'), quantity CHECK > 0, settled_product_id FK products, equipment_id Y FK, status CHECK IN ('PENDING_APPROVAL','POSTED','REJECTED','CANCELLED') 기본 POSTED, transaction_id Y FK stock_transactions, trade_document_id Y FK trade_documents, note, [AUD]. CHECK (CONVERT면 trade_document_id 필수, 장비가 있으면 수량 1) | 대차 정산 기록. 정산할 때마다 한 줄이라 나눠서 정산할 수 있다. settled_product_id는 실제로 주고받은 제품(같은 모델이면 대차 품목과 같음). 동급 모델이면 PENDING_APPROVAL로 만들고 `APPROVE` 권한자가 승인하면 POSTED, 반려하면 REJECTED (#40, review_requests). 재고가 움직이면 그 처리 묶음, 전환이면 만든 거래 문서를 연결. 그 처리 묶음을 취소하면 CANCELLED |
| loan_document_changes | id, loan_id FK, line_id FK Y, field_name, old_value Y, new_value Y, reason, changed_by, changed_at | 대차 문서 변경 이력. trade_document_changes와 같은 일반형. 정산 방식(#42)·기한(#72) 등 바뀐 항목마다 한 줄. 2026-11-03 loan_method_changes에서 바꿈 |

### 5.10 trash.trash_events — 삭제·복구 이력

| 컬럼 | 설명 |
|---|---|
| id, entity_type, entity_id, action CHECK IN ('DELETE','RESTORE'), reason Y, acted_by, acted_at | 각 모듈의 삭제·복구 이벤트를 모은 목록 (PRJ-05). 실제 삭제 표시는 각 테이블의 [DEL] 컬럼. 복구는 원장·배정·납품 행을 만들지 않는다 (NFR-05) |

### 5.11 cost — 금액 (권한 분리 스키마)

금액은 이 스키마에만 저장한다. COST_VIEW·COST_EDIT 권한이 없는 사용자는 API에서도 접근할 수 없다 (COST-04, 권한 매트릭스 3.3). 산식·세금·원가 배분은 ISS-4, ISS-16 확정 후 컬럼을 보완한다.

| 테이블 | 컬럼 | 설명 |
|---|---|---|
| line_prices | trade_line_id PK·FK, unit_price numeric(19,4), currency char(3) FK currencies (기본 KRW), exchange_rate numeric(18,6) (기본 1), exchange_rate_date date Y, unit_price_krw numeric(19,4), tax_type Y, [AUD] | 거래 품목별 매입 단가·판매 단가 (COST-01). 변경 이력은 cost_changes (2026-11-23 변경, #91). 비우기는 행 삭제(#92). 완료 문서도 고칠 수 있고 취소 문서는 불가(#73). 귀속월이 마감되면 바꾸거나 비울 수 없다(#103) |
| extra_costs | id, project_id FK, cost_type CHECK IN ('SHIPPING','INSTALL','RENTAL','OTHER'), amount numeric(20,4) (2026-11-26, V4), currency FK currencies (기본 KRW), exchange_rate numeric(18,6) (기본 1), exchange_rate_date Y, amount_krw numeric(18,2), cost_date, trade_document_id Y, loan_document_id Y, note, [AUD], [DEL]. CHECK (cost_type \<> 'RENTAL' OR loan_document_id IS NOT NULL) (2026-11-23 추가) | 운송·설치비, 차입 대여료 등 부대비용 (COST-03). 소프트 삭제(#92), 대여료는 차입 대차 필수(INV-82). RENTAL은 차입 대차 문서(loan_document_id) 연결 필수이고 실제 쓴 프로젝트마다 한 줄, 다른 임차료는 OTHER (#74, INV-68) |
| loan_fees | loan_document_id PK·FK, amount numeric(20,4) (2026-11-26, V4), currency FK currencies (기본 KRW), exchange_rate numeric(18,6) (기본 1), exchange_rate_date Y, amount_krw numeric(18,2), [AUD] | 대여 방향 대차 문서의 대여료(수익). 프로젝트 마진에 넣지 않음. 차입 대여료는 extra_costs의 RENTAL로 기록 (#74, INV-68) |
| opening_costs (2026-11-09 추가) | ledger_entry_id PK·FK ledger_entries, unit_cost numeric(19,4) CHECK >= 0, currency FK currencies (기본 KRW), exchange_rate numeric(18,6) (기본 1), exchange_rate_date Y, unit_cost_krw numeric(19,4), note(평가 근거) Y, [AUD] | 초기 재고 단가. 초기 재고(OPENING) 원장 행마다 선택해서 넣는 평가 단가로, 이동평균의 출발점이 된다. 넣지 않은 재고가 나가면 원가 미확인. `STOCK_ADJUST` 그리고 `COST_EDIT` 권한자만 입력(INV-74). OPENING 행인지는 트랜잭션 검증 (#81, INV-74) |
| currencies | code char(3) PK (ISO 4217), name, minor_unit smallint (표시·반올림 자리수), is_active boolean | 통화 목록. 초기값 KRW(minor_unit 0, 활성), USD(minor_unit 2, 비활성). 비활성 통화는 입력 불가 |
| cost_changes | id, target_type CHECK IN ('LINE_PRICE','EXTRA_COST','LOAN_FEE','OPENING_COST'), target_id uuid, field_name, old_value text Y, new_value text Y, reason Y, changed_by, changed_at. 인덱스 (target_type, target_id) | 금액 변경 이력 (2026-11-23 추가, #91, INV-83). 넣기·바꾸기·비우기·삭제를 같은 트랜잭션에서 남긴다. 대상은 여러 테이블이라 FK 없이 target_type·target_id로 가리킨다. `COST_VIEW` 권한자만 조회 |

**금액 귀속월과 마감 (2026-11-23, #103·INV-85):** 네 금액 테이블에 attribution_basis varchar(20) NOT NULL과 attribution_date date Y를 둔다. 기준값: line_prices DOCUMENT_DATE(기본)·FULFILLED_DATE·MANUAL, extra_costs COST_DATE(기본)·MANUAL, loan_fees SETTLED_DATE(기본)·DUE_DATE·MANUAL, opening_costs CUTOVER_DATE(기본)·MANUAL. CHECK ((attribution_basis = 'MANUAL') = (attribution_date IS NOT NULL)). 귀속월이 마감되면 금액을 바꾸거나 비울 수 없고, 비어 있는 단가를 처음 넣는 것만 허용.

**외화 기준일 (2026-11-23, #94·INV-84):** 네 금액 테이블 모두 CHECK (currency = 'KRW' OR exchange_rate_date IS NOT NULL). 환율과 기준일은 사람이 직접 넣고 출처는 기록하지 않는다. 기준일은 거래 문서 일자와 별개.

**다중 통화 대비:** 현재는 매입·매출 모두 원화다. 확장을 위해 통화·환율·원화 환산 컬럼을 미리 두되, KRW일 때는 환율 1·환산 금액 = 금액으로 자동 저장하고 화면에서 숨긴다. 외화를 활성화하면 통화·환율 입력 칸이 보인다. 환율 적용 기준일·환율 출처·환차손익 처리는 외화 사용 시점에 정한다 (ISS-4).

**원가·마진 (2026-11-09 확정, #79–#81):** 원가·마진·재고 평가액은 테이블에 저장하지 않고 조회할 때 계산한다. 단가를 나중에 고칠 수 있어(#73) 저장하면 어긋나기 때문이다. 시리얼 장비는 입고 발주 품목의 line_prices(개별 원가), 직납은 delivery_lines.purchase_line_id의 단가, 수량 품목 창고 출고는 제품별 이동평균(발주 입고 단가와 opening_costs로 계산), 차입 장비는 정산 방식별(재고 원장 처리 규칙 13.2). 부가세 제외, 줄 금액은 통화 소수 자리로 반올림한 뒤 합계. 상세 규칙은 재고 원장 처리 규칙 14절. 조회가 느려지면 그때 계산 결과 캐시를 추가한다. 차입 장비를 다른 프로젝트가 쓴 경우 원가는 실제 사용 프로젝트로 귀속한다.

### 5.12 importing.files — 증빙 첨부 (5단계, 2026-11-24 변경)

| 테이블 | 컬럼 | 설명 |
|---|---|---|
| files | id, target_type CHECK IN ('TRADE_DOCUMENT'), target_id, original_name, content_type CHECK IN ('application/pdf','image/jpeg','image/png'), storage_key UNIQUE, content_hash varchar(64), size_bytes CHECK (0 \< size_bytes ≤ 20971520), uploaded_by, uploaded_at, note Y, [DEL]. INDEX (target_type, target_id), INDEX (content_hash) | 거래 문서에 붙이는 증빙 파일(#104). 문서 내용은 사람이 직접 입력하고, 파일은 증빙으로만 남는다. 문서 하나에 여러 개. 첨부 대상은 종류+ID(다형 참조, FK 없음)라 나중에 납품·대차 등에 붙일 때는 CHECK 목록만 늘린다. 올릴 때마다 별도 행·별도 파일로 저장하고(내용이 같아도 공유하지 않음), content_hash는 같은 내용 경고(#77)에만 쓴다. 떼면 소프트 삭제, 디스크 파일은 영구 보관. storage_key는 최상위 폴더 기준 상대 경로 `trade-document/2026/11/{id}.pdf` |

PDF 읽기(import_jobs: 추출 결과 확인 후 작성 중 문서로 저장)는 보류했다(2026-11-24). 다시 하게 되면 이 테이블에 파일을 올리고 작업 테이블을 더한다.

### 5.13 common.idempotency_keys — 중복 요청 키 (2026-11-23 추가)

| 테이블 | 컬럼 | 설명 |
|---|---|---|
| idempotency_keys | idempotency_key varchar(64) PK, user_id, action varchar(100), request_hash varchar(64), status CHECK IN ('IN_PROGRESS','DONE') 기본 IN_PROGRESS, response_status Y, response_body json Y(2026-11-25 jsonb → json, 받은 그대로 보관해 다시 보낸 응답의 필드 순서를 유지), created_at, completed_at Y. CHECK (DONE이면 response_status·completed_at 필수). INDEX (created_at) | 업무 동작의 중복 요청 방지 (INV-08, API 명세서 1.5절). 재고·장비·문서 상태가 바뀌는 모든 업무 동작에 쓴다 |

- 키는 처리 전에 따로 저장(IN_PROGRESS)하고, 업무 처리와 같은 트랜잭션에서 응답을 저장하며 DONE으로 바꾼다. 업무 오류(4xx)로 끝나도 그 응답을 저장하고, 서버 오류(5xx)면 키를 지워 다시 보낼 수 있게 한다.
- 같은 키가 다시 오면: DONE이면 저장한 응답을 그대로, IN_PROGRESS면 409 `REQUEST_IN_PROGRESS`, user_id·action·request_hash 중 하나라도 다르면 400.
- 7일 지난 행은 매일 지운다. `stock_transactions.request_id`는 그대로 둔다(재고 처리의 DB 차원 중복 방지).
- common 모듈이 갖는 유일한 테이블이다.

### 5.14 admin 스키마 — review_requests / notifications / integrity_check_results (2026-11-23 추가)

| 테이블 | 컬럼 | 설명 |
|---|---|---|
| review_requests | id, request_type CHECK IN (승인: 'DISPOSAL','LOAN_OUT','EQUIVALENT_SETTLEMENT','COUNT_DIFFERENCE' / 확인: 'UNPLANNED_RECEIPT','SERIAL_CHANGE','LOAN_DUE_CHANGE'), target_type, target_id, status CHECK IN ('PENDING','APPROVED','REJECTED','CONFIRMED') 기본 PENDING, summary Y, requested_by, requested_at, decided_by Y, decided_at Y, decision_reason Y, version. 부분 유니크 (request_type, target_type, target_id) WHERE status = 'PENDING' | 승인·확인 요청. 승인·확인 대기함(O1)의 원본. 승인 종류는 APPROVED·REJECTED로, 확인 종류는 CONFIRMED로만 끝난다(CHECK). 처리하면 처리자·시각 필수, 반려는 사유 필수 (#61). 같은 대상에 대기 중 요청은 하나 |
| notifications | id, recipient_user_id, notification_type CHECK IN ('REVIEW_REJECTED','INTEGRITY_ALERT','ALLOCATION_RELEASED','WARRANTY_EXPIRING'), title, message Y, target_type Y, target_id Y, created_at, read_at Y. INDEX (recipient_user_id, read_at) | 알림. 반려하면 요청자에게(실사 차이는 실사 담당자에게, #61), 정합성 점검에서 어긋난 것이 나오면 `AUDIT_VIEW` 권한자마다 한 줄 (O5) |
| integrity_check_results | id, check_code (C1~C15), target_type, target_key varchar(200), detail jsonb, first_found_at, last_found_at, resolved_at Y. 부분 유니크 (check_code, target_type, target_key) WHERE resolved_at IS NULL | 정합성 점검 결과. 어긋남을 찾으면 행을 만들고(이미 열린 행이 있으면 last_found_at만 갱신), 다음 점검에서 다시 나오지 않으면 resolved_at을 채운다. 열린 행이 있으면 월 마감 차단 (O5). 대상 키는 재고 키처럼 여러 값일 수 있어 문자열로 둔다 |

- review_requests의 대상(느슨한 참조, 외래 키 없음): 폐기 → stock_transactions(DRAFT), 대여 출고 → loan_documents, 동급 정산 → loan_settlements, 실사 차이 → stock_counts, 발주 외 입고 → stock_transactions, 시리얼 수정 → equipment_events, 기한 변경 → loan_document_changes.
- 반려하면 대상은 바꾸지 않는다(#61). 실사 차이를 반려하면 실사가 세기 단계(IN_PROGRESS)로 돌아간다.
- 대상 테이블의 approved_by·approved_at(stock_transactions, loan_documents, stock_counts)은 그대로 두고 승인 결과를 빨리 보는 용도로 쓴다. 승인·반려의 원본 기록은 review_requests다.
- 미확인 시리얼 장비(#60)는 요청을 만들지 않고 equipment.serial_status로 목록을 만든다. 번호를 채우면 저절로 빠진다.

> 🟡 **확정 전**: 알림을 시스템 화면 안에서만 보여 줄지, 이메일로도 보낼지 정하지 않았다. 지금 구조는 화면 안 알림 기준이다. 모듈 이름 admin도 디렉토리 구조에 아직 반영 전이다.

## 6. 주요 관계 요약

```txt
products ─┬─< ledger_entries >── stock_transactions
          ├─< stock_balances
          ├─< equipment ─< equipment_events
          │             └── warranties ─< warranty_changes
          └─< bundle_components >── bundles

locations ─┬─< ledger_entries        (warehouses 1 ─< N locations, 외부 위치는 partners 참조)
           └─< stock_balances

projects ─< trade_documents ─< trade_lines ─── line_prices (cost)
    │                               │
    │                               ├─< allocations (PLANNED)
    │                               └─< delivery_lines (sales_line / purchase_line)
    ├─< deliveries ─< delivery_lines ─< delivery_returns
    ├─< allocations (PROJECT)
    └─< loan_documents ─< loan_lines ─< loan_settlements
                │
                └─< allocations (LOAN_REPAY)

ledger_entries.reversal_of_entry_id ──> ledger_entries (원본, 1회만)
stock_transactions.source_type/source_id ──> 업무 모듈 (느슨한 참조)
```

- 마스터(products, locations, partners)를 참조하는 외래 키는 건다.
- inventory는 업무 모듈(project, delivery, loan)을 외래 키로 참조하지 않고 source_type/source_id로만 기록한다. 모듈 경계 유지 목적.
- 업무 모듈은 inventory의 원장·잔액을 조회만 하고, 쓰기는 InventoryCommands로 요청한다.

## 7. 협의 이슈에 따라 바뀔 수 있는 부분

| 이슈 | 영향 테이블·컬럼 | 현재 가정 |
|---|---|---|
| ISS-1 권한 | auth.permissions, roles, role_permissions | 2026-11-26: 권한 13개 + `USER_MANAGE` 권한자가 만드는 역할, 기본 역할 6개(#106). 승인 범위가 정해지면 권한을 나눌 수 있다 |
| ISS-2 시리얼 범위 | equipment.serial_no 유니크 범위 | 제품별 유니크, 미확인은 NULL |
| ISS-3 보증 기준 | warranties.basis, 만료 알림 테이블 | 2026-11-23 확정(#95): basis CHECK IN ('DELIVERY','MANUFACTURER','PURCHASE','MANUAL'), 만료 30일 전 알림 WARRANTY_EXPIRING |
| ISS-4·16 금액 산식·원가 | cost 스키마 전체, 원가 계산 결과 테이블 | 단가·부대비용 저장, 통화·환율 컬럼 준비 (KRW 기본값). 원가·마진 산식과 초기 재고 단가(opening_costs)는 확정(#79–#81), 계산 결과 테이블은 두지 않음. 환율 기준일·출처와 금액 마감은 외화 사용 시 결정 |
| ISS-6 구성비 | bundle_components | 구조만 생성 |
| ISS-7 출고·납품 분리 | deliveries.transaction_id, equipment.status | 두 방식 모두 수용 가능한 구조 |
| ISS-8 동명 프로젝트 | projects.project_code | 코드로 구분, 이름 중복 허용 |
| ISS-9 중복 판정 | trade_documents 유니크, importing.files.content_hash | 거래처+문서번호는 차단(삭제 목록 제외), 같은 파일 내용은 경고 (#77). 2026-11-24: PDF 읽기 보류, 증빙 첨부만(PDF·JPG·PNG, 20MB), 첨부는 영구 보관, 서버 디스크 (#104) |
| ISS-10 운영 | trash 보존 기간, 백업 | 영구 보존 |
| ISS-14 제품 코드 변경 | products.item_code, 코드 변경 이력 테이블 | 확정(#78). 원장에 스냅샷이 있어 지난 기록은 유지됨. 변경 이력은 product_changes(2026-11-03 추가) |
