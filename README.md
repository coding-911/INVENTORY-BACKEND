# Asset-Management
자산 관리 자동화 시스템 (백엔드). 설계 문서는 `docs/`.

## 로컬 실행

필요한 것: JDK 25, Docker Desktop

1. `docker/.env.example`을 `docker/.env`로 복사하고 `POSTGRES_PASSWORD`에 아무 값이나 넣는다. `.env`는 Git에 올리지 않는다.
2. `./gradlew bootRun` — `local` 프로필로 켜지며 `docker/compose.local.yml`의 PostgreSQL 18을 함께 켜고 Flyway 마이그레이션을 적용한다. 앱은 http://localhost:8080
3. 빌드·테스트: `./gradlew build` (Docker 필요: 테스트는 Testcontainers로 별도 DB를 띄운다)

로컬 DB를 처음부터 다시 만들려면 `docker compose -f docker/compose.local.yml down -v`.
