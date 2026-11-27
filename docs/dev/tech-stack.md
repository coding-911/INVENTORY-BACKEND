# 백엔드 기술 스택

> 원본(노션): https://app.notion.com/p/422b82ca31e58168bf53c6862f5c4c07  
> 내보낸 날짜: 2026-11-27. **노션이 원본이다.** 이 파일과 노션이 다르면 노션을 따른다.

> 🧰 백엔드에서 쓰는 기술과 버전, 쓰지 않는 기술과 이유를 정리한다 (2026-11-24 결정). 코드 작성 규칙은 [개발 컨벤션](https://app.notion.com/p/c9a23b67b2234b118a564059d27fcce2), 패키지 구조는 [디렉토리 구조](https://app.notion.com/p/408b82ca31e5802da847f03723e75a89)를 본다.

> 🎨 이 페이지는 전부 요구사항 정의서 v1.1 이후 새로 작성한 내용이다.

## 1. 전제

- 사내 리눅스 서버 한 대에 앱·DB·첨부 파일을 둔다. 동시 사용 규모·백업 방식은 ISS-10에서 정한다.
- 모듈형 모놀리스 하나(실행 파일 하나)다. 서비스를 나누지 않는다 (ADR "Spring Boot + 모듈형 모놀리스 채택").
- 가장 중요한 것은 재고 숫자가 틀어지지 않는 것이다. 그래서 트랜잭션·행 잠금·DB 제약에 기대고, 서버를 늘리는 기술(분산 캐시·메시지 큐)은 쓰지 않는다.
- 소스는 GitHub에서 관리한다.

## 2. 기술과 버전

**버전 규칙**: Spring Boot가 관리하는 라이브러리(★)는 버전을 따로 적지 않고 Boot의 버전 목록(BOM)을 따른다. Boot가 관리하지 않는 것만 `gradle/libs.versions.toml`에 버전을 적는다. Boot 패치 버전(4.1.x)은 나오는 대로 올리고, 4.2 같은 다음 마이너 버전은 Modulith·springdoc이 따라오는 것을 확인한 뒤 올린다.

| 분류 | 기술 | 버전 | 용도·비고 |
|---|---|---|---|
| 언어 | Java (Eclipse Temurin) | 25 LTS | 2025-09 출시 장기 지원 버전. Spring Boot 4.1은 Java 17–27 지원 |
| 빌드 | Gradle (Kotlin DSL), Gradle Wrapper | 9.x | `build.gradle.kts`, 버전 목록 `libs.versions.toml`. Wrapper로 모두 같은 Gradle을 쓴다 |
| 프레임워크 | Spring Boot | 4.1.x (최신 패치) | Spring Framework 7 기반. 2026-06 정식 출시 |
| 웹 | Spring Web MVC, 내장 Tomcat 11 ★ | Boot 관리 | REST API. 반응형(WebFlux)은 쓰지 않는다. JPA·행 잠금과 맞지 않고 이 규모에 필요 없다 |
| 입력 검증 | Bean Validation (Hibernate Validator) ★ | Boot 관리 | 요청 DTO의 형식 검사. 업무 규칙 검사는 서비스에서 한다 |
| 모듈 구조 | Spring Modulith (core, events, test) | 2.x (Boot 4.1에 맞는 버전, BOM) | 모듈 경계 검사(ModularityTest), 모듈 간 이벤트, 모듈 단위 테스트. 이벤트 발행 기록을 DB에 남겨 실패한 처리를 다시 할 수 있다 |
| 인증·권한 | Spring Security 7, Spring Session JDBC ★ | Boot 관리 | 서버 세션 로그인 (ADR "인증 방식: 세션 로그인", 2026-11-25 OAuth2 + JWT에서 바꿈). 세션은 DB에 둔다. 비밀번호는 BCrypt 해시 |
| DB 접근 (쓰기) | Spring Data JPA, Hibernate 7 ★ | Boot 관리 | 엔티티 저장·수정, 낙관적 잠금(`@Version`), 재고 행 잠금(PESSIMISTIC_WRITE). UUID v7은 Hibernate 내장 생성기로 만든다 |
| DB 접근 (조회·집계) | JPA 프로젝션, JPA Specification, JdbcClient ★ | Boot 관리 | 목록은 필요한 열만 record로, 검색 조건 조합은 Specification, 집계·마진·정합성 점검은 SQL(JdbcClient) |
| 커넥션 풀 | HikariCP ★ | Boot 관리 | 기본 설정에서 시작하고 동시 사용 규모(ISS-10)를 보고 조정 |
| DB | PostgreSQL | 18 (18.x 최신 패치) | 모듈별 스키마. 공식 지원 2030-11까지. `uuidv7()` 내장. DDL은 18.7에서 검증(2026-11-24) |
| DB 마이그레이션 | Flyway (core + database-postgresql) ★ | Boot 관리 | 스키마 변경 이력. 운영에서는 Hibernate가 테이블을 만들지 않는다(`ddl-auto=validate`) |
| JSON | Jackson 3 ★ | Boot 관리 | 금액은 문자열, 기록 시각은 시간대 포함 (API 명세서 1.8) |
| API 문서 | springdoc-openapi (webmvc-ui) | 3.x | Boot 4 전용 버전. 코드에서 OpenAPI를 만들고, 프론트의 TypeScript 타입도 여기서 만든다. API를 바꾸는 PR에는 빌드가 만든 `docs/api/openapi.json`을 함께 커밋하고, CI가 최신인지 비교한다(프론트 저장소가 이 파일에서 타입을 만든다, ADR-18). 운영에서는 문서 화면을 끄거나 관리자만 |
| 코드 줄이기 | Lombok ★ | Boot 관리 | 쓸 수 있는 애너테이션을 제한한다 (개발 컨벤션 2절) |
| 객체 변환 | MapStruct | 1.6.x | 엔티티 → 응답 DTO만. 요청 → 엔티티에는 쓰지 않는다 (개발 컨벤션 3절). Lombok과 함께 쓸 때 `lombok-mapstruct-binding`을 넣는다 |
| 캐시 | Spring Cache + Caffeine ★ | Boot 관리 | 서버 메모리 캐시. 바뀌는 일이 드문 기준 정보처럼 짧게 캐시할 값만. 재고·금액은 캐시하지 않는다 |
| 일정 작업 | Spring Scheduling (`@Scheduled`) ★ | Boot 관리 | 매일 새벽 정합성 점검, 보증 만료 알림, 오래된 중복 요청 키 정리. 서버가 한 대라 중복 실행 방지(ShedLock)는 필요 없다 |
| 로그 | SLF4J + Logback, 구조화 로그(JSON) ★ | Boot 관리 | 운영은 JSON 한 줄 로그, 개발은 읽기 쉬운 형식. 비밀번호·세션 쿠키·금액은 로그에 남기지 않는다 |
| 추적 | Micrometer Tracing ★ | Boot 관리 | 요청마다 traceId를 만들어 로그와 오류 응답(`traceId`, API 명세서 1.4)에 넣는다. 외부 추적 서버는 두지 않는다 |
| 상태 확인 | Spring Boot Actuator, Micrometer ★ | Boot 관리 | `health`·`info`·`metrics`만 열고, 내부망에서만 접근 |
| 테스트 | JUnit, AssertJ, Mockito, Spring Boot Test ★ | Boot 관리 | 단위·통합·API 테스트 |
| 테스트 DB | Testcontainers (PostgreSQL 18 이미지) ★ | Boot 관리 | 실제 PostgreSQL로 동시성·불변 조건·점검 쿼리 테스트. H2 같은 메모리 DB는 쓰지 않는다(부분 유니크·트리거·NULLS NOT DISTINCT가 없음) |
| 코드 형식 | Spotless + Palantir Java Format | 최신 (Gradle 플러그인) | 빌드 때 형식을 검사하고 `spotlessApply`로 자동 정리. 4칸 들여쓰기 |
| 테스트 범위 | JaCoCo | Gradle 내장 | 테스트가 닿은 코드 비율 보고서. 기준치는 개발하며 정한다 |
| 실행 환경 | Docker, Docker Compose | Docker Engine 최신, Compose v2 | 앱·PostgreSQL·Nginx를 컨테이너로. 앱 이미지는 Temurin 25 JRE 기반, Boot의 계층형 jar |
| 웹 서버 | Nginx | stable | HTTPS, 프론트 화면(정적 파일) 제공, `/api`를 앱으로 전달. 업로드 한도 20MB에 맞춤. 첨부 폴더는 직접 서비스하지 않는다. 응답 헤더 `Referrer-Policy: same-origin`(화면 주소가 외부로 넘어가지 않게, 화면 목록 2절) |
| 서버 | 리눅스 사내 서버 | 배포판은 설치 때 정함 | 첨부 파일 `/srv/asset/files`, DB 데이터는 서버 디스크 볼륨 |
| 형상 관리 | Git, GitHub | — | main 브랜치 보호, Pull Request로 합침 |
| CI | GitHub Actions | — | Pull Request마다 형식 검사·빌드·전체 테스트(Testcontainers 포함). Gradle 캐시 사용. 비밀 값은 GitHub Secrets. 배포할 때는 Docker 이미지를 만들어 파일(tar)로 내려받을 수 있게 한다(3.1절) |

★ = Spring Boot가 버전을 관리하는 것.

## 3. 실행 구성

```txt
[브라우저] ──HTTPS──▶ [Nginx]
                         ├─ /        → 프론트 화면 (React 빌드 결과)
                         └─ /api/**  → [Spring Boot 앱 (Java 25)]
                                           ├─ [PostgreSQL 18]   데이터 볼륨
                                           └─ /srv/asset/files  첨부 파일
모두 한 대의 리눅스 서버, Docker Compose로 실행
```

- 설정은 환경별 파일(`application-local.yml`, `application-prod.yml`)에 두고, DB 비밀번호·첫 관리자 비밀번호(`ADMIN_PASSWORD`) 같은 비밀 값은 환경 변수로 넣는다 (NFR-01).
- 개발 PC에서도 Docker Compose로 PostgreSQL 18을 띄운다. Boot의 Docker Compose 연동으로 앱을 켜면 DB도 함께 켜진다. `./gradlew bootRun`이 `local` 프로필로 `docker/compose.local.yml`을 쓴다. 로컬 DB 비밀번호도 저장소에 두지 않고 `docker/.env`(Git 제외)에 두며, 저장소에는 `docker/.env.example`만 올린다 (2026-11-24).

### 3.1 배포 (2026-11-24)

**지금은 이미지 파일을 옮겨 수동으로 배포한다.** 서버에 GitHub 실행기를 두는 자동 배포는 나중에 붙인다.

```txt
[지금] main에 합침 → Actions: 테스트 → 이미지 빌드(태그 = 버전) → tar 파일을 Actions 결과물로 보관
       담당자가 내려받아 서버로 복사 → 서버에서 deploy.sh 실행
         (DB 백업 → docker load → docker compose up -d → 상태 확인)
[나중] 서버의 GitHub 실행기가 같은 deploy.sh를 실행 (승인 후)
```

- 나중에 자동화할 때 바꾸는 것이 없도록 지금부터 아래를 지킨다.
  - 이미지는 Actions에서만 만든다. 개발 PC에서 만든 이미지는 운영에 올리지 않는다.
  - 이미지 태그는 버전(예: `asset-backend:1.0.3`)이고 `latest`를 쓰지 않는다. 되돌릴 때는 이전 태그로 다시 띄운다.
  - 서버의 compose 파일은 태그를 환경 변수(`APP_VERSION`)로 받는다. 비밀 값은 서버의 `.env`에만 둔다.
  - 배포 절차는 백엔드 저장소의 `deploy/deploy.sh` 하나로 만든다(백엔드·프론트 저장소 분리, 디렉토리 구조 1절). 사람과 나중의 실행기가 같은 스크립트를 실행한다.
- Actions 결과물 보관 기간은 저장소 설정을 따른다. 운영에 올린 버전의 tar는 서버에도 최근 몇 개를 남겨 되돌릴 때 쓴다.
- Flyway 마이그레이션은 되돌리지 않는다. 그래서 `deploy.sh`는 앱을 바꾸기 전에 DB를 백업한다.

## 4. 쓰지 않는 것

| 기술 | 쓰지 않는 이유 | 대신 |
|---|---|---|
| Spring Cloud, Kafka 등 메시지 큐 | 서비스를 여러 개로 나눈 구조용이다. 우리는 앱 하나에 모듈만 나눴다 | Spring Modulith 이벤트 |
| Redis | 서버가 한 대라 분산 캐시·세션 공유가 필요 없다. 로그인 세션은 PostgreSQL에 둔다(Spring Session JDBC) | Caffeine, Spring Session JDBC |
| Elasticsearch, Kibana | 데이터량이 PostgreSQL 검색으로 충분한 규모다 | PostgreSQL 인덱스 |
| Spring Batch | 대량 일괄 처리가 없다 | `@Scheduled` |
| WebSocket, SSE | 알림은 "우선 화면 알림만"으로 정했다 | 화면이 주기적으로 알림 목록 조회 |
| WebFlux(반응형) | JPA·행 잠금과 맞지 않고 코드가 복잡해진다 | Web MVC |
| QueryDSL | 원래 프로젝트의 관리가 멈춰 커뮤니티 포크만 남았다 | JPA Specification, JdbcClient |
| H2 등 메모리 DB | PostgreSQL 전용 기능을 테스트할 수 없다 | Testcontainers |
| Apache Tika | 첨부 형식이 PDF·JPEG·PNG 세 가지뿐이다 | 파일 앞부분 서명 직접 확인 |
| ShedLock | 서버가 한 대다 | `@Scheduled` |
| AWS(EC2·RDS 등) 클라우드 | 사내 리눅스 서버에 둔다 | Docker Compose |

## 5. 아직 정할 것

> 🟡 **확정 전**
>
> - 자동 배포 전환 시점: 서버에서 `github.com`·`ghcr.io`로 나가는 HTTPS가 허용되는지 확인한 뒤, 서버에 GitHub 실행기를 두고 승인 후 `deploy.sh`를 실행하게 한다. 그때 이미지 전달을 tar 파일에서 GHCR로 바꿀지도 정한다
> - 백업: PostgreSQL 백업 방식과 주기, 첨부 폴더 백업 (ISS-10)
> - 모니터링: Prometheus·Grafana 도입 여부는 운영 규모를 보고 정한다. 지금은 Actuator와 로그만
> - 엑셀 내보내기(Apache POI): 필요 여부 미정

## 6. 참고

- [Spring Boot 4.1 System Requirements](https://docs.spring.io/spring-boot/4.1/system-requirements.html)
- [Spring Boot 4.1.0 출시](https://spring.io/blog/2026/06/10/spring-boot-4/)
- [Spring Modulith 2.0 GA](https://spring.io/blog/2025/11/21/spring-modulith-2-0-ga-1-4-5-and-1-3-11-released/)
- [Spring Session JDBC](https://docs.spring.io/spring-session/reference/http-session.html#httpsession-jdbc)
- [springdoc-openapi](https://github.com/springdoc/springdoc-openapi)
- [PostgreSQL 18 릴리스 노트](https://www.postgresql.org/docs/current/release-18-6.html)
