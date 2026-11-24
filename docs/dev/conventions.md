# 개발 컨벤션

> 원본(노션): https://app.notion.com/p/c9a23b67b2234b118a564059d27fcce2  
> 내보낸 날짜: 2026-11-24. **노션이 원본이다.** 이 파일과 노션이 다르면 노션을 따른다.

> 📐 백엔드 코드를 쓸 때 지키는 규칙이다 (2026-11-24). 쓰는 기술과 버전은 [백엔드 기술 스택](https://app.notion.com/p/422b82ca31e58168bf53c6862f5c4c07), 패키지·모듈 구조와 이름 규칙은 [디렉토리 구조](https://app.notion.com/p/408b82ca31e5802da847f03723e75a89) 4·8절, API 모양은 [API 명세서](https://app.notion.com/p/408b82ca31e580d19b7ee382dacd572b) 1절을 본다.

> 🎨 이 페이지는 전부 요구사항 정의서 v1.1 이후 새로 작성한 내용이다.

## 1. 기본

- Java 25 문법을 쓴다. 값만 담는 객체는 `record`, 정해진 값 목록은 `enum`, 분기는 switch 식·패턴 매칭을 쓴다.
- 코드 형식은 Spotless(Palantir Java Format)가 정한다. 커밋 전에 `./gradlew spotlessApply`, CI는 `spotlessCheck`로 막는다.
- null 대신 빈 목록·`Optional`(반환값에만)을 쓴다. 필드·인자에 Optional을 쓰지 않는다.

## 2. Lombok

| 구분 | 애너테이션 | 규칙 |
|---|---|---|
| 쓴다 | `@Getter`, `@RequiredArgsConstructor`, `@Slf4j`, `@Builder`, `@NoArgsConstructor(access = AccessLevel.PROTECTED)` | 생성자 주입은 `@RequiredArgsConstructor`와 `final` 필드. 엔티티의 기본 생성자는 JPA용으로 protected만. `@Builder`는 생성자에 붙이고 클래스에는 붙이지 않는다 |
| 쓰지 않는다 | `@Setter`, `@Data`, `@ToString`, `@EqualsAndHashCode`, `@AllArgsConstructor`, `@Value`, `@SneakyThrows` | 엔티티 값이 아무 데서나 바뀌는 것, 연관 엔티티를 따라가며 무한 반복·지연 로딩이 터지는 것, 필드 순서에 기대는 생성자를 막는다. 값 객체는 Lombok 대신 `record` |

- 요청·응답 DTO는 `record`라 Lombok이 필요 없다.
- 엔티티의 equals·hashCode는 쓰지 않거나, 필요하면 id만으로 직접 쓴다.

## 3. DTO와 MapStruct

**DTO는 용도별로 나눈다.** 엔티티의 모든 속성을 담은 DTO 하나를 돌려 쓰지 않는다.

| 종류 | 위치 | 이름 예 | 규칙 |
|---|---|---|---|
| 요청 | `{모듈}/web/request` | `ProductCreateRequest`, `ProductUpdateRequest`, `ReceiptRequest` | 동작마다 하나. Bean Validation으로 형식만 검사(`@NotNull`, `@Size` 등). 수정 요청은 바꿀 항목만 담고 `version`을 포함(API 명세서 1.6) |
| 응답 (하나) | `{모듈}/web/response` | `ProductResponse` | API 명세서 3절의 응답 객체와 같은 필드 |
| 응답 (목록 한 줄) | `{모듈}/web/response` | `ProductListItem` | 목록 화면에 필요한 필드만 |
| 다른 객체 가리키기 | `common` | `Ref(id, label)`, 또는 모듈별 `CategoryRef(id, code, name)` | 다른 객체는 `{id, 코드 또는 이름}`만 (API 명세서 3절) |
| 모듈 간 | `{모듈}/api/dto` | `StockMovementRequest`, `StockSnapshot` | 다른 모듈이 부르는 인터페이스용. 웹 요청·응답 객체와 섞지 않는다(디렉토리 구조 4절) |

**금액 필드**: 금액 보기 권한이 없으면 필드 자체가 없어야 한다(INV-83). 금액 없는 응답과 금액 있는 응답을 따로 두고(예: `TradeLineResponse` / `TradeLineWithPriceResponse`), 서비스가 권한을 보고 고른다. null로 채워 보내지 않는다.

**MapStruct 사용 범위**

| 경우 | 방법 |
|---|---|
| 상세 조회 (엔티티 → 응답 DTO) | MapStruct. DTO마다 변환 메서드 하나. DTO에 없는 엔티티 필드는 자동으로 무시된다 |
| 목록 조회 | 엔티티를 거치지 않는다. 쿼리에서 필요한 열만 골라 record로 바로 받는다(JPA 프로젝션 또는 JdbcClient) |
| 등록·수정 (요청 → 엔티티) | **MapStruct를 쓰지 않는다.** 엔티티의 생성 메서드나 업무 메서드(`document.confirm()`, `line.changeQuantity(…)`)로만 값을 바꾼다. 자동 복사는 검증과 변경 이력을 건너뛸 수 있다 |
| 모듈 간 DTO | MapStruct 가능 (엔티티 → `api/dto`) |

**공통 설정** (모든 매퍼가 `config`로 쓴다)

```java
@MapperConfig(
    componentModel = MappingConstants.ComponentModel.SPRING,
    injectionStrategy = InjectionStrategy.CONSTRUCTOR,
    unmappedTargetPolicy = ReportingPolicy.ERROR)   // DTO 필드를 못 채우면 빌드 실패
public interface CommonMapperConfig {}

@Mapper(config = CommonMapperConfig.class)
interface ProductMapper {
    ProductResponse toResponse(Product product);
    @Mapping(target = "category", source = "category")   // 이름이 다르거나 중첩이면 지정
    ProductListItem toListItem(Product product);
}
```

- 매퍼는 모듈의 `internal` 안에 두고 모듈 밖에서 부르지 않는다.
- 매퍼 안에 업무 로직(계산·권한 판단)을 넣지 않는다. 금액 계산·잔량 계산은 서비스나 엔티티에서 하고 결과만 옮긴다.

## 4. 엔티티

- setter가 없다. 만들 때는 생성 메서드(`TradeDocument.create(…)`)를, 바꿀 때는 업무 이름의 메서드를 쓴다. 메서드 안에서 상태 규칙을 검사한다.
- id는 UUID v7(Hibernate 내장 생성기). 수정·삭제 대상은 `@Version`을 둔다.
- **다른 모듈의 엔티티를 연관으로 잡지 않는다.** 다른 모듈은 id(UUID)로만 가리킨다(예: 원장은 `productId`만 가진다). 모듈 경계는 ModularityTest가 검사한다.
- 같은 모듈 안의 연관은 `@ManyToOne(fetch = LAZY)`만. EAGER, 연관을 따라 삭제(cascade REMOVE)는 쓰지 않는다(삭제는 소프트 삭제).
- 소프트 삭제는 `deleted_at`·`deleted_by`. 조회 기본 조건으로 `deleted_at IS NULL`을 건다(Hibernate `@SQLRestriction`). 삭제 목록 조회만 예외.
- 원장(`ledger_entries`)은 저장만 하고 수정·삭제 메서드를 두지 않는다(INV-01).
- 코드값은 Java enum으로 두고 DB에는 문자열로 저장한다(`@Enumerated(STRING)`). enum 이름 = DB CHECK 목록의 값.

## 5. 조회

- `spring.jpa.open-in-view=false`. 화면용 데이터는 서비스 안에서 다 만든다.
- 목록은 페이지 조회(API 명세서 1.7). 필요한 열만 고르고, 연관 때문에 쿼리가 줄줄이 나가는(N+1) 코드는 리뷰에서 막는다.
- 검색 조건 조합은 JPA Specification, 집계·마진·재고 현황·정합성 점검은 SQL(JdbcClient)로 쓴다. SQL 문자열에 값을 이어 붙이지 않고 항상 바인딩한다.

## 6. 트랜잭션과 잠금

- `@Transactional`은 서비스 클래스에만 붙인다. 조회 서비스는 `readOnly = true`.
- 업무 동작 하나 = 트랜잭션 하나. 처리 묶음은 전부 반영되거나 전부 반영되지 않는다(INV-07).
- 현재 재고 행은 PESSIMISTIC_WRITE로 잠근다. 여러 행을 잠글 때는 재고 키(제품 → 위치 → 상태 → 소유) 순서로 정렬해 잠가 교착을 피한다.
- 검사 순서는 API 명세서 1.10을 따른다(중복 요청 키 → 권한 → 업무 날짜 → 실사 잠금 → 재고·배정 → 장비).
- 모듈 간 후속 처리는 이벤트로. 같은 트랜잭션에서 반영해야 하는 것(INV-75 등)은 동기 리스너, 알림처럼 늦어도 되는 것은 커밋 뒤 리스너(`@ApplicationModuleListener`)로 한다.

## 7. 오류 처리

- 업무 규칙 위반은 `BusinessException(ErrorCode, details)`을 던진다. `ErrorCode`는 enum 하나에 HTTP 상태와 기본 메시지를 함께 둔다(API 명세서 1.4).
- 응답은 공통 예외 처리기(`@RestControllerAdvice`) 한 곳에서 만든다. 컨트롤러에서 try-catch로 응답을 만들지 않는다.
- DB 제약 위반(유니크·CHECK)은 제약 이름으로 오류 코드에 연결한다(예: `ux_products_item_code` → `PRODUCT_ITEM_CODE_DUPLICATE`). 제약 이름은 DDL 세 파일에서 같다.
- 예상하지 못한 오류는 500 `INTERNAL_ERROR`와 traceId만 돌려주고, 상세는 로그에만 남긴다.

## 8. 날짜·시간·금액

| 값 | Java 타입 | DB 타입 |
|---|---|---|
| 업무 날짜 | `LocalDate` | `date` |
| 기록 시각 | `Instant` (응답은 `OffsetDateTime` +09:00) | `timestamptz` |
| 수량 | `int` | `integer` |
| 단가·금액·환율 | `BigDecimal` (double 금지) | `numeric` |

- "오늘"은 서버 시계가 아니라 `Clock`(Asia/Seoul)을 주입받아 계산한다. 테스트에서 날짜를 고정할 수 있게 하기 위해서다(미래 날짜·7일·마감 검사).

## 9. 테스트

- 불변 조건 테스트 이름은 ID로 시작한다. 예: `INV03_동시_출고_시_음수_재고_불가` (불변 조건 목록 11절).
- DB가 필요한 테스트는 Testcontainers PostgreSQL 18. 컨테이너는 테스트 전체에서 하나를 같이 쓴다.
- 통합 테스트 끝에 정합성 점검 쿼리(C1–C15)를 돌려 0행인지 확인한다.
- 모듈 하나만 띄우는 테스트는 `@ApplicationModuleTest`를 쓴다.

## 10. Git·Pull Request·버전 (2026-11-24)

코드는 Claude Code가 쓰고 사람이 검토·승인한다. 그래서 main에는 사람의 승인 없이 아무것도 들어가지 않게 한다.

| 항목 | 규칙 |
|---|---|
| 브랜치 | GitHub Flow. `main`과 짧게 쓰는 작업 브랜치. 이름 `feat/`·`fix/`·`refactor/`·`test/`·`docs/`·`chore/` 뒤에 내용(예: `feat/inventory-receipt`). 이슈 번호가 있으면 앞에 붙인다. 합친 브랜치는 지운다 |
| main 보호 | 직접 push 금지. Pull Request로만 합침. **GitHub Actions 통과 + 사람 1명 승인** 필수. Claude Code는 PR을 만들 수 있지만 스스로 합치지 않는다 |
| 커밋 메시지 | Conventional Commits 형식, 설명은 한국어. `{종류}({모듈}): {설명}`. 예: `feat(inventory): 발주 입고 API 추가`. 관련 규칙·불변 조건 번호는 본문에(`#88`, `INV-35`) |
| Pull Request 크기 | API 하나 또는 기능 하나 단위로 작게. 코드와 그 코드의 테스트(해당 INV 테스트 포함)를 같은 PR에 넣는다. 사람이 검토할 수 있는 크기를 넘으면 나눈다 |
| Pull Request 설명 | `.github/pull_request_template.md`를 따른다. 넓은 것 → 좁은 것 순서: **요약 → 근거 → 기술적 의사결정 → 바뀐 파일 → 테스트 → DB 마이그레이션 → 확인 필요 → 관련 PR**. 항목마다 1~3줄로 짧게 쓰고, 해당 없으면 "없음". 바뀐 파일에는 고친 노션 페이지도 적는다. DB 마이그레이션이 있으면 제목에 `[DB]`. 문서와 다르게 구현한 것은 이유와 함께 "확인 필요"에 적는다(2026-11-24) |
| 합치는 방식 | Squash merge. PR 하나 = main 커밋 하나, 커밋 메시지는 PR 제목(위 형식) |
| 버전·배포 | SemVer(`1.2.3`). 배포할 때 main에 `v1.2.3` 태그를 달면 Actions가 그 버전의 이미지 파일을 만든다(백엔드 기술 스택 3.1) |
| 저장소 안내 파일 | 각 저장소 최상위에 `CLAUDE.md`를 둔다. 이 페이지의 핵심 규칙, 빌드·테스트 명령, 노션 문서(API 명세서·테이블 정의서·재고 원장 처리 규칙·불변 조건 목록) 링크를 적어 Claude Code가 매번 읽게 한다. 로컬 작업 폴더 최상위에도 두 저장소를 안내하는 `CLAUDE.md`를 둔다. 노션 문서 사본은 각 저장소의 `docs/`에 둔다. `CLAUDE.md`는 Claude Code가 읽는 로컬 파일이라 Git에 올리지 않고(`.gitignore`), `docs/`는 설계·규칙의 근거이므로 Git에 올린다. 설계가 바뀌면 노션과 `docs/` 사본을 함께 고친다(2026-11-24) |
| 저장소 구성 | 백엔드(`backend`)와 프론트엔드(`frontend`)는 Git 저장소를 따로 둔다(2026-11-24). 두 저장소에 걸친 변경(API 응답이 바뀌어 화면도 고쳐야 하는 경우 등)은 저장소마다 브랜치와 PR을 따로 만들고 PR 설명에 서로 링크한다. API를 바꾸는 백엔드 PR이 먼저 합쳐진다 |
