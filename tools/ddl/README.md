# tools/ddl — DDL 생성기와 검증 스크립트

설계 단계에서 `docs/db/ddl/`의 DDL 파일 4개를 만들고 검증하던 도구다. **개발이 시작되면 DB 구조의 원본은 Flyway 마이그레이션**이므로, 이 도구는 첫 마이그레이션을 만들 때와 설계 단계 결정을 다시 확인할 때만 쓴다. 새 변경은 이 도구가 아니라 새 마이그레이션 파일로 한다.

## 파일

| 파일 | 역할 |
|---|---|
| `gen.py` | 테이블·컬럼·FK·CHECK·인덱스 정의(원본). `out/asset_schema_postgresql.sql`(전체), `out/asset_schema_erdcloud_mysql.sql`(ERD 도구용) 생성 |
| `gen3.py` | `gen.py`를 읽어 제약을 핵심(v1, 26개)과 나중(v2, 109개)으로 나누고 `asset_v1_create.sql`, `asset_v2_constraints.sql`, `asset_prod_full.sql` 생성. 보강 제안 P1–P5(11건) 포함 |
| `proposals.sql` | 검증용: 전체 DDL에 보강 제안만 더한 것 |
| `verify.sh` | PostgreSQL 18에서 (v1 + v2) = 운영 최종본 = (전체 DDL + 제안) 인지 카탈로그로 비교 |
| `test/run_check_tests.sh` | 점검 쿼리 C9–C15 시험: 정상 시험 데이터는 0행, 일부러 틀어 놓은 11가지는 모두 잡혀야 한다 |
| `test/c9_c15.sql`, `test/c9_c15_seed_uuid.sql` | 위 시험의 쿼리와 시험 데이터 |

## 사용

```bash
cd tools/ddl
python3 gen.py out && python3 gen3.py out          # out/ 에 DDL 생성
export PGHOST=localhost PGPORT=5432 PGUSER=postgres PGPASSWORD=...   # PostgreSQL 18
./verify.sh                    # IDENTICAL 두 번, tables 54 / columns 639
./test/run_check_tests.sh      # [정상] 0행, X1–X11 모두 결과 행 있음
```

- `verify.sh`·`run_check_tests.sh`는 검증용 DB(`dba`, `dbb`, `dbc`, `dbv1`, `dbt`)를 지웠다 다시 만든다. 운영·개발 DB 서버에서 실행하지 않는다.
- 2026-11-24 기준 결과: 테이블 54, 컬럼 639, 외래 키 102, 핵심 제약 26, v2 제약 109, 보강 제안 11. 생성 결과는 `docs/db/ddl/`과 바이트 단위로 같다.
- 2026-11-26: `docs/db/ddl/asset_v2_constraints.sql`에서 `uq_roles_code`·`ck_user_permissions_1`을 손으로 뺐다. Flyway V5(역할·권한 체계, #106)가 user_permissions를 지우고 roles에 부분 유니크를 걸었기 때문이다. 그래서 이 파일은 더 이상 gen3.py 생성 결과와 같지 않다. v2는 나중에 Flyway 마이그레이션으로 옮겨 적용한다(CLAUDE.md 4절).
