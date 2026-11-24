# 디렉토리 구조

> 원본(노션): https://app.notion.com/p/408b82ca31e5802da847f03723e75a89  
> 내보낸 날짜: 2026-11-24. **노션이 원본이다.** 이 파일과 노션이 다르면 노션을 따른다.

> 🧱 Spring Boot **모듈형 모놀리스**. 업무 도메인별로 패키지(모듈)를 나누고, 모듈 간 의존 규칙은 Spring Modulith 테스트로 강제한다. 근거: [Spring Boot + 모듈형 모놀리스 채택](https://app.notion.com/p/408b82ca31e581648affd2bdab8c7380)

## 1. 저장소 최상위

```txt
자산관리/                    로컬 작업 폴더 (Git 저장소 아님)
├── CLAUDE.md                작업 폴더 안내: 저장소가 둘이고 어디서 무엇을 하는지
└── workspace/
    ├── backend/             ★ 백엔드 저장소 (GitHub, 이 문서)
    │   ├── CLAUDE.md        백엔드 규칙·명령·문서 안내
    │   ├── docs/            노션 설계 문서 사본, DDL, 점검 쿼리
    │   ├── tools/ddl/       DDL 생성·검증 도구 (설계 단계 참고용)
    │   ├── docker/          docker-compose.yml, PostgreSQL 초기 설정
    │   ├── deploy/          deploy.sh (백엔드 기술 스택 3.1)
    │   └── build.gradle.kts, src/ …   (2절)
    └── frontend/            프론트엔드 저장소 (GitHub) React + TypeScript + Vite
        ├── CLAUDE.md        (프론트 개발 시작 때 만든다)
        └── docs/            프론트에 필요한 노션 문서 사본 (API·권한)
```

2026-11-24 변경: 백엔드와 프론트엔드는 **Git 저장소를 따로** 둔다. 로컬에서는 작업 폴더의 `workspace/` 아래에 두 저장소를 나란히 둔다. 각 저장소는 자기 `docs/`를 가진다(노션이 원본, docs는 사본). 이 문서의 나머지 경로(`backend/…`)는 백엔드 저장소 최상위 기준이다.

> ⚠️ **확정 전**: `docker/`·`deploy/`는 일단 백엔드 저장소에 둔다. 프론트 빌드 결과(정적 파일)를 Nginx에 넣는 방법과 프론트 배포 절차는 프론트 개발을 시작할 때 정한다.

## 2. backend 전체 구조

> ℹ️ **기본 패키지:`kr.co.unipoint.asset`(확정)**<br>회사 도메인 [unipoint.co.kr](http://unipoint.co.kr)을 거꾸로 쓴 뒤 시스템명 asset을 붙였다. 조직 개편과 취급 제품 확장에 대비해 팀 이름과 제조사 이름(vertiv)은 넣지 않는다.

```txt
backend/
├── build.gradle.kts
├── settings.gradle.kts
├── gradle/
└── src/
    ├── main/
    │   ├── java/kr/co/unipoint/asset/
    │   │   ├── AssetApplication.java
    │   │   ├── common/          공통: 감사 컬럼, 예외, 응답 형식, 중복 요청 키
    │   │   ├── user/            사용자·역할·로그인
    │   │   ├── product/         제품 마스터, 구성 묶음
    │   │   ├── warehouse/       창고·보관 위치
    │   │   ├── inventory/       ★ 재고 원장 (처리 묶음, 원장, 재고 조회)
    │   │   ├── equipment/       시리얼 개별 장비, 보증
    │   │   ├── partner/         거래처·담당자
    │   │   ├── project/         프로젝트, 매입·매출·선발주 문서, 비교
    │   │   ├── allocation/      스탁·프로젝트 배정
    │   │   ├── delivery/        발주·입고 잔량, 납품, 직납
    │   │   ├── loan/            차입·대여 (대차)
    │   │   ├── cost/            원가·판매 금액·마진
    │   │   ├── importing/       증빙 첨부 (5단계, PDF 읽기는 보류)
    │   │   ├── trash/           삭제 목록·복구
    │   │   ├── dashboard/       홈 집계 (읽기 전용)
    │   │   └── admin/           승인·확인 대기함, 알림, 정합성 점검 (2026-11-23 추가)
    │   └── resources/
    │       ├── application.yml
    │       ├── application-local.yml
    │       ├── application-prod.yml
    │       └── db/migration/    Flyway SQL
    └── test/
        └── java/kr/co/unipoint/asset/
            ├── ModularityTest.java
            ├── support/         Testcontainers 공통 설정, 테스트 데이터 빌더
            ├── inventory/       모듈별 테스트 (패키지 구조 동일)
            └── ...
```

## 3. 모듈 목록

| 모듈 | 역할 | 주요 요구사항 | DB 스키마 | 개발 단계 |
| --- | --- | --- | --- | --- |
| common | 감사 컬럼, 공통 예외·응답, 중복 요청 키, 시간 처리. 모든 모듈이 쓰는 공유 모듈로 지정(`@Modulithic(sharedModules = "common")`). 2026-11-23 shared에서 이름 변경 | NFR-04, NFR-06 | common (중복 요청 키 테이블만, 2026-11-23) | 1 |
| user | 사용자, 역할, 로그인, 금액 접근 권한, 로그인 토큰 저장(Spring Authorization Server) | NFR-08, COST-04 | auth | 1 |
| product | 제품 마스터, 품목군, 시리얼 관리 여부, 구성 묶음 | PROD-01~05, KIT-01 | product | 1 |
| warehouse | 창고, 보관 위치 | WH-01 | warehouse | 1 |
| partner | 고객사·공급사, 담당자 | PARTY-01~02 | partner | 1 |
| inventory | 처리 묶음, 원장, 입출고·이동·실사 조정·취소/정정, 현재 재고 | WH-02~07, WH-09, HIST-01~02, NFR-02~05 | inventory | 2 |
| equipment | 시리얼 장비, 상태 전이, 이동 이력, 보증 | ASSET-01~04 | equipment | 2 / 4 |
| project | 프로젝트, 거래 문서(매입·매출·선발주), 품목, 비교·복사 | PRJ-01~05, PO-01~05, CMP-01~04 | project | 2 / 3 (프로젝트·거래 문서 등록·조회는 2단계, 2026-11-23) |
| allocation | 공용 스탁·프로젝트 배정, 예정 배정, 배정 가능 수량 | ALLOC-01~04 | allocation | 3 |
| delivery | 발주·입고 잔량, 납품 회차, 부분 납품, 직납 | DEL-01~04, WH-08 | delivery | 2 / 3 (발주 입고·창고 출고는 2단계, 2026-11-23) |
| loan | 차입·대여 문서, 정산(현물·거래 전환·원물 반환)과 정산 기록, 차입·대여 잔량 | 재고 원장 처리 규칙 13절 | loan | 3 |
| trash | 삭제 목록, 복구 (이벤트 기반) | PRJ-05, NFR-05 | trash | 3 |
| cost | 매입 원가, 판매 금액, 마진, 부대비용, 통화, 대여료 | COST-01~03 | cost | 4 |
| dashboard | 홈 프로젝트 수·품목군별 재고 집계 (조회 전용) | UI-02~03 | — | 4 |
| importing | 증빙 첨부 파일(올리기·목록·열기·떼기)과 서버 디스크 저장. PDF 읽기(추출·확인 후 저장)는 보류 (2026-11-24, #104) | PO-02~03 | importing | 5 |
| admin | 승인·확인 요청과 대기함, 알림, 정합성 점검 결과·마감 차단 (2026-11-23 추가) | 확정 사항 #61·#84, 가이드 O1·O5 | admin | 2 |

> 💡 **정의서 대비 모듈을 더 나눈 부분:** 시리얼 장비(equipment), 배정(allocation), 금액(cost)은 v1.1에서 새로 생긴 영역이다. 각각 상태 규칙과 권한 규칙이 독립적이라 project나 inventory 안에 넣으면 두 모듈이 비대해진다. 배정은 보유 재고(inventory)와 예정 물량(delivery) 양쪽을 참조하므로 별도 모듈이 경계를 지키기 쉽다.

## 4. 모듈 내부 구조

모든 모듈은 같은 모양을 따른다. 예시는 핵심 모듈인 `inventory`.

```txt
inventory/
├── package-info.java              @ApplicationModule 선언, 허용 의존 명시
├── api/                           ◀ 다른 모듈이 접근할 수 있는 유일한 영역
│   ├── InventoryCommands.java     입고·출고·이동·조정·취소 요청 (인터페이스)
│   ├── StockQueries.java          보유 수량 조회 (인터페이스)
│   ├── dto/
│   │   ├── StockMovementRequest.java
│   │   ├── StockMovementLine.java
│   │   └── StockSnapshot.java
│   └── event/
│       └── StockTransactionPosted.java
├── web/                           REST 컨트롤러 (/api/v1/inventory/...)
│   ├── StockTransactionController.java
│   ├── StockQueryController.java
│   └── request/ , response/       HTTP 전용 요청·응답 객체
└── internal/                      ◀ 모듈 밖에서 참조 금지
    ├── domain/
    │   ├── StockTransaction.java      처리 묶음 (헤더)
    │   ├── LedgerEntry.java           원장 라인 (LowData)
    │   ├── TransactionType.java       초기재고·입고·출고·이동·조정·취소·정정
    │   └── TransactionStatus.java     DRAFT, POSTED
    ├── repository/
    │   ├── StockTransactionRepository.java
    │   ├── LedgerEntryRepository.java
    │   └── CurrentStockRepository.java    잠금 조회(PESSIMISTIC_WRITE) 포함
    └── service/
        ├── InventoryCommandService.java   api 인터페이스 구현, @Transactional
        ├── StockQueryService.java
        └── PostingValidator.java          미등록 제품·수량·재고 초과 검증
```

| 영역 | 역할 | 외부 접근 |
| --- | --- | --- |
| `api/` | 다른 모듈이 호출하는 인터페이스, DTO, 발행 이벤트 | 허용 |
| `web/` | HTTP 엔드포인트. api 또는 internal 서비스를 호출 | 프론트엔드만 |
| `internal/` | 엔티티, 리포지토리, 서비스 구현 | **금지** |

- 엔티티는 모듈 밖으로 나가지 않는다. 다른 모듈에는 `api/dto`만 넘긴다.
- 컨트롤러 요청·응답 객체(`web/request`, `web/response`)와 모듈 간 DTO(`api/dto`)는 분리한다. 화면이 바뀌어도 모듈 간 계약은 그대로 유지하기 위해서다.

## 5. 의존 규칙

```txt
importing ─┐
dashboard ─┤
trash ─────┤   (이벤트 수신)
cost ──────┼──▶ project ──▶ partner
delivery ──┤       │
allocation ┤       ▼
equipment ─┴──▶ inventory ──▶ warehouse
                    │
                    └──▶ product

모든 모듈 ──▶ common, user(권한 확인)
승인·확인·알림이 필요한 모듈(inventory·equipment·loan) ──▶ admin (api만)
admin ──(ReviewDecided 이벤트)──▶ 대상 모듈이 승인·반려 결과를 처리
```

| 모듈 | 의존 가능 대상 |
| --- | --- |
| product, warehouse, partner | common |
| inventory | product, warehouse, common |
| equipment | product, warehouse, inventory, partner, common |
| project | product, partner, common |
| allocation | inventory, equipment, project, delivery, product, common |
| delivery | project, inventory, equipment, product, partner, common |
| loan | inventory, equipment, allocation, project, partner, product, common |
| cost | project, product, user, loan, common |
| trash | common (다른 모듈의 삭제·복구 이벤트를 수신) |
| dashboard | project, inventory, product, common (조회 API만) |
| importing | project(첨부 대상 문서 확인·label), user(열기 권한), common. 삭제·복구는 다른 모듈처럼 이벤트로 trash에 알린다 (2026-11-24) |
| admin | user, common. 다른 모듈은 admin의 api(요청·알림 만들기)를 호출하고, 승인·반려 결과는 admin이 이벤트로 알려 대상 모듈이 처리한다(순환 의존 방지). 정합성 점검은 여러 스키마를 읽기 전용 SQL로 조회한다 (2026-11-23) |

**핵심 규칙**

1. **원장을 쓰는 곳은 inventory 하나뿐이다.** delivery가 창고 경유 출고를 할 때도 `InventoryCommands`를 호출할 뿐 원장 테이블에 직접 쓰지 않는다.
2. **inventory는 업무 모듈(project·delivery·allocation)을 모른다.** 요청 출처는 `source_type`, `source_id`, `reference_no`로만 기록한다.
3. **직납은 inventory를 호출하지 않는다.** delivery와 equipment만 갱신한다 (WH-08).
4. **project의 매입·매출 수량은 재고를 바꾸지 않는다** (PO-04). 차이 수량 표시는 조회만 한다.
5. **삭제·복구는 이벤트로 처리한다.** 각 모듈이 `…Deleted` / `…Restored` 이벤트를 발행하고 trash가 목록을 관리한다. 복구가 입출고·배정·납품을 재생성하지 않는다 (NFR-05).
6. **순환 의존 금지.** 역방향 알림이 필요하면 이벤트를 쓴다.

**검증 테스트**

```java
class ModularityTest {
    ApplicationModules modules = ApplicationModules.of(AssetApplication.class);

    @Test
    void verifiesModularStructure() {
        modules.verify();   // internal 참조, 순환 의존, 허용되지 않은 의존 시 실패
    }

    @Test
    void writesDocumentation() {
        new Documenter(modules).writeDocumentation();   // 모듈 다이어그램 자동 생성
    }
}
```

## 6. 리소스와 DB 마이그레이션

```txt
resources/
├── application.yml            공통 설정
├── application-local.yml      로컬 (docker-compose PostgreSQL)
├── application-prod.yml       운영 (환경 변수로 접속 정보 주입)
└── db/migration/
    ├── V1_000__create_schemas.sql
    ├── V1_100__product_init.sql
    ├── V1_200__warehouse_init.sql
    ├── V1_300__inventory_init.sql
    ├── V1_310__inventory_ledger_guard.sql    원장 UPDATE·DELETE 차단 트리거
    ├── V1_400__partner_init.sql
    └── ...
```

- 파일명: `V{대버전}_{모듈 번호}{순번}__{모듈}_{설명}.sql`. 모듈 번호를 100 단위로 나눠 충돌을 줄인다.
- 모듈별 PostgreSQL 스키마(`product`, `inventory` …)를 `V1_000`에서 만든다.
- 애플리케이션 DB 계정에는 `inventory.ledger_entries`의 UPDATE·DELETE 권한을 주지 않는다 (HIST-02, NFR-08).
- DB 접속 정보는 yml에 쓰지 않고 환경 변수로 넣는다 (NFR-01).

## 7. 테스트 구조

| 위치 | 종류 | 내용 |
| --- | --- | --- |
| `ModularityTest` | 구조 | 모듈 경계·의존 규칙 검증 |
| `{모듈}/internal/...Test` | 단위 | 검증 로직, 상태 전이, 계산 |
| `{모듈}/...IntegrationTest` | 통합 | Testcontainers PostgreSQL로 트랜잭션·잠금 검증 |
| `{모듈}/web/...ApiTest` | API | 권한, 요청 검증, 응답 형식 |
| `acceptance/` | 검수 | 검수 시나리오 AT-01~21을 자동화한 테스트 |

동시성 검수(AT-06 마지막 재고 동시 출고, AT-10 장비 중복 출고)는 통합 테스트에서 여러 스레드로 같은 요청을 보내 한 건만 확정되는지 확인한다.

## 8. 네이밍 규칙

| 대상 | 규칙 | 예시 |
| --- | --- | --- |
| 패키지 | 소문자 단수 | `inventory`, `delivery` |
| 모듈 공개 인터페이스 | `{도메인}Commands` / `{도메인}Queries` | `InventoryCommands`, `StockQueries` |
| 서비스 구현 | `{도메인}CommandService` / `{도메인}QueryService` | `InventoryCommandService` |
| 컨트롤러 | `{리소스}Controller` | `StockTransactionController` |
| 이벤트 | 과거형 | `StockTransactionPosted`, `TradeDocumentDeleted` |
| API 경로 | `/api/v1/{모듈}/{리소스}` 단수형(2026-11-23 복수형에서 변경), kebab-case. 모듈의 대표 리소스는 모듈 경로 자체 | `/api/v1/inventory/stock-transaction`, `/api/v1/product/{id}` |
| DB 테이블 | snake_case 복수형, 모듈 스키마 접두 | `inventory.ledger_entries` |

## 9. 새 모듈 추가 절차

1. `kr.co.unipoint.asset.{모듈}` 아래 `api/`, `web/`, `internal/`과 `package-info.java`를 만든다.
2. `package-info.java`에 허용 의존 모듈을 선언한다.
3. Flyway에 모듈 번호를 할당하고 스키마·테이블을 만든다.
4. 이 문서의 모듈 목록과 의존 규칙 표를 갱신한다.
5. `ModularityTest`가 통과하는지 확인한다.
