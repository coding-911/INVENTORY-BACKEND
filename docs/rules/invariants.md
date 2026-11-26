# 불변 조건 목록

> 원본(노션): https://app.notion.com/p/795f92f07cab4e38860d4e9f1e6df2d0  
> 내보낸 날짜: 2026-11-24. **노션이 원본이다.** 이 파일과 노션이 다르면 노션을 따른다.

> 🛡️ 불변 조건은 처리 순서가 어떻든, 요청이 동시에 들어오든, 버그가 있든 항상 참이어야 하는 규칙이다. 각 조건마다 어디서 막는지(강제 위치)와 근거를 함께 적는다. 규칙의 배경은 [재고 원장 처리 규칙](https://app.notion.com/p/53340b01efa54f16a6217503509ca182), 컬럼은 [테이블 정의서](https://app.notion.com/p/408b82ca31e58080bd5deb903f3026c6)를 본다.

> 🎨 이 페이지는 전부 요구사항 정의서 v1.1 이후 새로 작성한 내용이라 파란 글씨로 표기한다.

## 1. 강제 위치

| 표기 | 위치 | 성격 |
|---|---|---|
| DB | DB 제약·트리거 | 애플리케이션에 버그가 있어도 막힌다. 가장 강하다 |
| TX | 트랜잭션 검증 | 서비스가 잠금을 잡은 상태에서 검사하고, 위반이면 처리 묶음 전체를 롤백한다 |
| ARCH | 모듈 경계 테스트 | ModularityTest가 금지된 의존을 발견하면 빌드를 실패시킨다 |
| 점검 | 정합성 점검 쿼리 | 매일 새벽과 월 마감 직전에 실행한다. 결과가 0행이어야 정상이다 (10절) |
| 테스트 | 자동 테스트 | 동작으로만 확인할 수 있는 조건 (권한별 응답, 복구 동작 등) |

- 재고 숫자나 금액이 틀어지는 조건은 TX에 더해 DB에서 한 번 더 막는다.
- TX로만 막는 조건은 점검 쿼리로 나중에 다시 확인한다.
- 모든 불변 조건에는 자동 테스트가 최소 하나 있어야 한다 (11절).

> ⚠️ DB 제약은 두 단계로 건다. 처음 생성용 DDL(v1)에는 핵심 제약 26개만 들어가고, 나머지는 서비스 테스트 후 v2에서 추가한다 ([테이블 정의서](https://app.notion.com/p/408b82ca31e58080bd5deb903f3026c6) 0절). 아래 표에서 강제 위치가 DB인 조건 중 v1에 없는 것(INV-17, 18, 25, 31, 38, 51, 57 등)은 v2 적용 전까지 서비스 검증과 테스트로만 막힌다.

## 2. 재고 원장

| ID | 불변 조건 | 강제 위치 | 근거 |
|---|---|---|---|
| INV-01 | 확정된 원장 행은 수정·삭제되지 않는다 | DB | 트리거 `trg_ledger_entries_append_only`, 앱 DB 계정에 UPDATE·DELETE 권한 없음 (HIST-02) |
| INV-02 | 원장 행의 수량은 0이 아니다 | DB | `ck_ledger_entries_4` |
| INV-03 | 현재 재고는 어떤 재고 키에서도 음수가 아니다 | DB + TX | `ck_stock_balances_4`, 현재 재고 행 PESSIMISTIC_WRITE 잠금 (AT-06) |
| INV-04 | 현재 재고 = 같은 재고 키의 원장 수량 합계 | TX + 점검 | 원장 INSERT와 현재 재고 갱신을 한 트랜잭션에서 처리, 점검 C1 |
| INV-05 | 재고 키(제품 × 위치 × 상태 × 소유)마다 현재 재고 행은 하나다 | DB | `ux_stock_balances_key` (NULLS NOT DISTINCT) |
| INV-06 | 자사 소유면 소유 업체가 비어 있고, 타사 소유면 소유 업체가 있다 | DB | 원장·현재 재고·실사 품목·장비의 소유 CHECK |
| INV-07 | 처리 묶음은 전부 반영되거나 전부 반영되지 않는다 | TX | @Transactional, 묶음 단위 확정 (NFR-02) |
| INV-08 | 같은 요청은 한 번만 반영된다 (중복 클릭·재시도). 같은 키로 다른 사람·다른 동작·다른 내용을 보내면 막힌다 | DB + TX | `uq_stock_transactions_request_id`, 모든 업무 동작은 `common.idempotency_keys` PK (2026-11-23, API 명세서 1.5절) |
| INV-09 | 쌍으로 기록하는 처리(이동·검수 판정·소유 전환)는 수량 합이 0이다 | TX + 점검 | `pair_id`, 점검 C4 |
| INV-10 | 원장 행은 한 번만 취소된다 | DB | `uq_ledger_entries_reversal_of_entry_id` |
| INV-11 | 취소 행은 원본과 재고 키·업무 날짜가 같고 수량은 반대다. 취소 행 자체는 다시 취소할 수 없다 | TX (+ DB 제안 P5) | 재고 원장 처리 규칙 10절, 확정 사항 #21·#24 |
| INV-12 | 취소한 뒤에도 재고가 음수가 되지 않는다. 뒤 처리(출고·배정·납품)가 걸린 행은 취소할 수 없다 | TX | 확정 사항 #22 |
| INV-13 | 원장을 쓰는 모듈은 inventory 하나뿐이다 | ARCH | 원장 리포지토리는 `inventory/internal`, ModularityTest |
| INV-14 | 과거 날짜로 처리해도 그 날짜부터 오늘까지 날짜별 마감 재고가 음수가 되지 않는다 | TX | 9.2, 확정 사항 #13 |
| INV-15 | 업무 날짜는 미래일 수 없고, 마감된 달일 수도 없다 | TX (+ DB 제안 P4) | 9.2, 확정 사항 #18 |
| INV-16 | `RECORD_CORRECT` 권한이 없는 사람이 넣는 업무 날짜는 최근 7일 이내다. 재고 조정·초기 재고·기준일 이전 등록(`STOCK_ADJUST`)은 제외 | TX | 확정 사항 #14·#106 (2026-11-26 "입력자"를 권한으로 바꿈) |

## 3. 시리얼 장비

| ID | 불변 조건 | 강제 위치 | 근거 |
|---|---|---|---|
| INV-17 | 같은 제품에 같은 시리얼 번호는 하나뿐이다 | DB | `ux_equipment_product_serial` (중복 범위는 ISS-2 결과에 따름) |
| INV-18 | 시리얼이 확정된 장비는 시리얼 번호가 있다 | DB | `ck_equipment_5` |
| INV-19 | 시리얼 장비는 한 시점에 한 곳(위치·상태·소유)에만 있다. 장비별 원장 합계는 0 또는 1이다 | TX + 점검 (+ DB 제안 P2) | 점검 C2·C3 |
| INV-20 | 장비 상태와 원장 위치가 일치한다. 예: 정상 재고 ↔ 자사 창고 정상 +1, 납품 완료 ↔ 장비 원장 합계 0. 장비의 현재 위치·소유도 원장과 같다 (점검 C12) | TX + 점검 | [도메인 상태 전이도](https://app.notion.com/p/2ecaec8fe036423eb619cb790a66b1ae) |
| INV-21 | 장비 상태는 상태 전이도에 있는 경로로만 바뀐다. 종료 상태(교체됨·폐기·공급사 반품·타사로 이전·상환됨·입고 취소)에서는 더 바뀌지 않는다 | TX | 재고 원장 처리 규칙 6절. 전이표 전체를 단위 테스트로 검증 |
| INV-22 | 장비 처리 날짜는 그 장비의 마지막 처리 날짜보다 앞서지 않는다 | TX | 확정 사항 #19, `equipment.last_event_date` |
| INV-23 | 시리얼 품목의 입고 수량 = 등록한 장비 수 ("미확인" 장비 포함) | TX | 8.3, 확정 사항 #60 |
| INV-24 | 장비 1대에 활성 배정은 1건뿐이다 | TX (+ DB 제안 P1) | AT-10 장비 중복 출고 |
| INV-25 | 장비 1대에 보증은 1건이고, 종료일은 시작일 이후다 | DB | `uq_warranties_equipment_id`, `ck_warranties_2` |
| INV-56 | 기준일 이전 납품 장비는 원장 없이 납품 완료로 생기고, 납품일은 기준일 이전이다. 창고 재고·회사 보유 자산에 들어가지 않는다 | TX + 점검 (+ DB 코드 목록) | 재고 원장 처리 규칙 9.4, 확정 사항 #50, `ck_equipment_6`, 점검 C7 |
| INV-61 | 시리얼 번호를 고치거나 미확인 시리얼을 채울 때도 중복 검증(INV-17)을 거친다. 시리얼 수정은 사유가 필수이고 원장을 바꾸지 않는다. 고객에게 납품한 적이 있는 장비는 관리자만 고칠 수 있고, 이전·이후 번호를 같은 트랜잭션에서 장비 이력에 남긴다 | TX | 확정 사항 #59·#60, INV-53 |
| INV-69 | 이미 넣은 보증 날짜를 바꾸면 사유가 있다(미확인을 처음 채울 때는 없어도 됨). 승계 원 장비의 보증이 미확인이면 승계한 장비도 미확인으로 시작한다 | TX | 확정 사항 #75, `warranty_changes.reason` |

## 4. 거래 문서·입고·납품

| ID | 불변 조건 | 강제 위치 | 근거 |
|---|---|---|---|
| INV-26 | 거래 품목의 기준일 이전 처리 수량 + 처리 수량 + 마감 수량 ≤ 문서 수량 (허용 오차 0, 매입·매출 공통) | DB | `ck_trade_lines_4` |
| INV-27 | 발주에 연결한 입고의 제품 = 발주 품목의 제품 | TX | 8.3 |
| INV-28 | 완료·취소된 문서와 잔량 마감된 품목에는 새 처리를 연결할 수 없다 | TX | 확정 사항 #10, 11.1 |
| INV-29 | 확정 문서의 수량은 처리 수량(기준일 이전 처리 포함)·배정 수량 밑으로 줄일 수 없다 | DB (처리 수량) + TX (배정 수량) | `ck_trade_lines_4`, 확정 사항 #26 |
| INV-30 | 일부라도 처리된 문서(기준일 이전 처리 수량이 있는 문서 포함)는 취소할 수 없다 (잔량 마감만 가능) | TX | 확정 사항 #27 |
| INV-31 | 같은 거래처 안에서 문서번호는 중복되지 않는다. 삭제 목록의 문서는 제외하고 취소된 문서는 포함한다. 모든 등록 방식에 같이 적용한다 (#77, 2026-11-24 PDF 읽기 보류) | DB | `ux_trade_documents_partner_docno` |
| INV-32 | 반품 수량 ≤ 납품 수량 | DB | `ck_delivery_lines_2` |
| INV-33 | 매입·매출 문서의 수량은 재고를 바꾸지 않는다 | ARCH | project → inventory 의존 금지 (PO-04) |
| INV-34 | 직납은 창고 재고를 바꾸지 않는다 | TX + 테스트 | WH-08. 직납 전후로 현재 재고가 그대로인지 확인 |
| INV-55 | 기준일 이전 처리 수량은 0 이상이고, 관리자만 첫 월 마감 전까지 입력·변경한다 | DB + TX | `ck_trade_lines_6`, 확정 사항 #48·#49 |
| INV-57 | 고객 반품은 납품 품목 또는 기준일 이전 납품 장비 중 하나에 연결된다. 장비로 연결하면 수량은 1이다 | DB | `ck_delivery_returns_2`, 확정 사항 #52 |
| INV-58 | 기준일은 하나다. 초기 재고 처리는 모두 같은 업무 날짜다 | TX + 점검 | 확정 사항 #53, 점검 C6 |
| INV-59 | 수리 입고는 수리 출고 건에 연결한다. 초기 재고 기록에 연결할 수 있는 것은 그 장비(또는 수량)가 기준일에 바로 그 수리처에 초기 재고로 들어간 경우뿐이다. 수량 품목은 그 초기 재고 수량을 넘어 돌아올 수 없다 | TX | 확정 사항 #55, 재고 원장 처리 규칙 9.4 |
| INV-60 | 대여처 위치에 자사 재고가 생기는 것은 승인된 대여 출고이거나, 관리자가 대차 문서에 연결해 넣은 초기 재고뿐이다. 타사 소유 초기 재고도 그 업체의 대차 문서(차입)에 연결돼야 한다 | TX | 확정 사항 #44·#54·#56, INV-41·42 |
| INV-65 | 스탁 상시 프로젝트는 하나만 있고(예약 코드 STOCK) 완료·취소·삭제되지 않는다 | DB (코드) + TX | `uq_projects_project_code`, 확정 사항 #65 |
| INV-66 | 프로젝트는 연결 문서(삭제 목록 포함)가 없을 때만 삭제된다. 작성 중·확정 문서가 남아 있으면 완료되지 않고, 모든 문서가 취소됐거나 문서가 없을 때만 취소된다 | TX | 확정 사항 #66 |
| INV-67 | 완료된 문서에서 바꿀 수 있는 것은 메모와 금액뿐이고, 금액은 금액 수정 권한자만 바꾼다. 취소된 문서는 금액도 바꿀 수 없다. 월 마감은 금액 수정을 막지 않는다 | TX | 확정 사항 #73, COST-04 |
| INV-70 | 사용 중지된 제품은 새 거래 품목·입고·초기 재고·대차 품목에 쓸 수 없다 | TX | 확정 사항 #78, `products.is_active` |
| INV-71 | 재고(모든 위치·상태·소유), 작성 중·확정 문서의 품목, 활성 배정, 대차 잔량이 남은 제품은 사용 중지할 수 없다. 이력이 있는 제품은 삭제되지 않는다 | TX (+ DB FK) | 확정 사항 #78, PROD-04. 삭제는 참조 FK가 한 번 더 막는다 |
| INV-75 | 저장해 두는 수량은 원본 기록의 합계와 같다. 거래 품목의 처리된 수량(매입·선발주 = 입고·공급사 반품·오류 조정 + 직납, 매출 = 납품 − 반품, 대차 전환 문서 = 전환 정산 수량), 배정 소진 수량 = 소진 이력 합계, 납품 품목 반품 수량 = 취소되지 않은 반품 기록 합계. 바뀔 때는 원본 기록과 같은 트랜잭션에서 바꾼다 | TX + 점검 | 확정 사항 #82, 점검 C9–C11 |

## 5. 배정

| ID | 불변 조건 | 강제 위치 | 근거 |
|---|---|---|---|
| INV-35 | 보유 재고에서 잡은 활성 배정의 합계 ≤ 자사 창고의 정상 재고 (소유 무관) | TX + 점검 | 현재 재고 행 잠금 아래에서 계산, 점검 C5, ISS-11 |
| INV-36 | 정상 재고를 줄이는 모든 처리(출고·이동·재고 조정·정상→불량 검수 판정·취소)는 확정 후에도 INV-35를 지킨다. 배정분을 출고하면 같은 트랜잭션에서 배정을 소진한다 | TX | 확정 사항 #38 |
| INV-37 | 소진 수량 ≤ 배정 수량 | DB | `ck_allocations_2` |
| INV-38 | 배정 대상은 프로젝트와 차입 상환 중 정확히 하나다 | DB | `ck_allocations_4` |

## 6. 차입·대여

| ID | 불변 조건 | 강제 위치 | 근거 |
|---|---|---|---|
| INV-39 | 정산 수량 ≤ 대차 수량 | DB | `ck_loan_lines_2` |
| INV-76 | 대차 품목의 정산 수량 = 확정(POSTED)된 정산 기록 합계. 정산 기록과 같은 트랜잭션에서 바꾼다. 동급 모델 정산은 승인 전(PENDING_APPROVAL)이거나 반려되면 수량에 들어가지 않는다. 전환 정산은 거래 문서가, 장비 정산은 수량 1이 필수다 | TX + 점검 (+ DB) | 2026-11-23 `loan_settlements` 추가, 점검 C13, `ck_loan_settlements_1`·`_4`·`_5` |
| INV-40 | 원물 반환(③) 방식으로 빌린 장비는 영구 납품할 수 없고 임시 설치만 할 수 있다. 창고를 거치지 않고 고객사로 바로 가면 차입 직납이 아니라 차입 직접 임시 설치로만 들어오고, 고객사 현장에 바로 들어오는 차입 입고는 ③ 방식에만 허용한다 (#71) | TX | 13.6 |
| INV-41 | 대여 출고는 정상 상태이면서 배정되지 않은 자사 재고만, 관리자 승인 후에 할 수 있다 | TX | 확정 사항 #43·#44 |
| INV-42 | 차입한 타사 재고의 소유 업체 = 대차 문서의 상대 업체 | TX | 13.1 |
| INV-43 | 정산이 끝난 대차 문서는 정산 방식을 바꿀 수 없다 | TX | 확정 사항 #42 |
| INV-44 | 타사 소유 재고는 회사 보유 자산에 들어가지 않는다. 대여 중인 자사 장비는 정산 전까지 들어간다 | TX (조회) + 테스트 | 13.4 |

## 7. 마감·실사

| ID | 불변 조건 | 강제 위치 | 근거 |
|---|---|---|---|
| INV-45 | 한 달에 마감 기록은 하나다 | DB | `uq_period_closings_period` |
| INV-46 | 마감된 달에는 원장 행을 추가할 수 없다. 마감된 달 처리의 취소도 막히며, 열린 기간의 조정으로 처리한다 | TX (+ DB 제안 P4) | 9.3, 확정 사항 #16·#24 |
| INV-47 | 마감 스냅샷 = 그달 말일까지의 원장 합계 | 점검 | 다시 마감하면 새 버전을 만들고 이전 버전은 보관 |
| INV-48 | 실사가 진행 중인 범위에는 일반 처리를 확정할 수 없다. 관리자 예외로 처리한 제품은 재실사 대상으로 표시한다 | TX | 확정 사항 #29–31. 현재 재고 잠금과 같은 경로에서 확인 |
| INV-49 | 실사 조정의 업무 날짜 = 실사 기준일 | TX | 확정 사항 #37 |
| INV-78 | 해결되지 않은 정합성 점검 결과가 있으면 월 마감을 할 수 없다. 같은 항목·대상의 열린 점검 결과는 하나다 | TX + DB | 정합성 점검 알림 대응(O5), `admin.integrity_check_results`, `ux_integrity_check_results_open` (2026-11-23) |
| INV-63 | 재고 조정은 실사 건 또는 마감된 달의 원래 처리 중 정확히 하나를 근거로 갖고 사유가 있다. 오류 조정은 관리자만 할 수 있다 | TX | 확정 사항 #63 |
| INV-64 | 오류 조정에 발주 품목을 연결하면 같은 트랜잭션에서 그 품목의 처리 수량을 같은 만큼 바꾼다. 처리 수량은 0 이상이고 INV-26을 지킨다 | TX (+ DB 범위) | 확정 사항 #62, `ck_trade_lines_2`·`ck_trade_lines_4` |

## 8. 금액·권한·이력

| ID | 불변 조건 | 강제 위치 | 근거 |
|---|---|---|---|
| INV-50 | 금액 조회 권한이 없는 사용자의 API 응답에는 금액 필드가 없다 | 테스트 | COST-04, API 테스트 |
| INV-51 | 환율은 0보다 크고, 통화는 등록된 코드만 쓴다 | DB | 금액 테이블의 환율 CHECK, `currencies` FK |
| INV-52 | 원화 금액은 환율이 1이고, 원화 환산 금액 = 금액이다 | TX (+ DB 제안 P3) | ISS-4 금액 결정 |
| INV-53 | 확정 문서(완료 문서의 금액 포함, #73)·배정·장비·보증·대차 정산 방식·대차 기한(#72)·제품의 Item Code와 사용 여부(#78)가 바뀌면 같은 트랜잭션에서 이력을 남긴다 | TX | `*_changes`, `*_events` 테이블 |
| INV-54 | 휴지통에서 복구해도 입출고·배정·납품이 다시 생기지 않는다 | 테스트 | NFR-05 |
| INV-62 | 승인이 필요한 처리(폐기·대여 출고·동급 모델 정산·실사 차이)는 승인 전이거나 반려되면 원장·장비·문서를 바꾸지 않는다. 반려는 사유가 필수이고, 반려한 사람·시각·사유가 승인·확인 요청에 남는다 | TX + DB (반려 사유) + 테스트 | 확정 사항 #5·#36·#40·#43·#61, `admin.review_requests`, `ck_review_requests_5`·`_6` |
| INV-77 | 같은 대상에 대기 중인 승인·확인 요청은 하나다. 승인 종류는 승인·반려로만, 확인 종류는 확인으로만 끝난다. 발주 외 입고·시리얼 수정·대차 기한 변경은 같은 트랜잭션에서 확인 요청을 만든다 | DB + TX | 확정 사항 #9·#59·#72, `ux_review_requests_pending`, `ck_review_requests_3`·`_4` (2026-11-23) |
| INV-68 | 부대비용 유형 대여료는 차입 대차 문서에 연결되고, 대차 문서의 대여료(`loan_fees`)는 대여 방향 문서에만 있다. 대여 대여료는 프로젝트 마진에 들어가지 않는다 | TX + 점검 | 확정 사항 #74, LOAN-10, 점검 C8 |
| INV-72 | 이력 있는 제품의 Item Code 변경과 사용 중지·다시 사용은 관리자만 하고, 코드 변경은 사유가 필수다. 같은 트랜잭션에서 제품 변경 이력을 남기고, 지난 처리 기록의 당시 코드는 바뀌지 않는다 | TX | 확정 사항 #78, `product_changes` |
| INV-73 | 합계·마진은 부가세를 뺀 원화 환산 금액으로 계산하고, 합계는 반올림한 줄 금액의 합과 같다. 원가·마진은 저장하지 않고 같은 입력이면 항상 같은 값이 나온다. 단가를 알 수 없는 물건의 원가는 0이 아니라 "미확인"이다 | 테스트 | 확정 사항 #79·#80, COST-02·03. 재고 원장 처리 규칙 14절 예시 금액으로 검증 |
| INV-74 | 초기 재고 단가는 초기 재고(OPENING) 원장 행에만, 행마다 하나 있고 0 이상이다. `STOCK_ADJUST`와 `COST_EDIT` 권한이 모두 있는 사람만 넣거나 고친다(2026-11-26) | DB (행당 하나·단가 범위) + TX (OPENING 행, 권한) | 확정 사항 #81, `opening_costs` PK·`ck_opening_costs_1` |
| INV-79 | 기준 정보(제품·품목군·창고·위치·거래처·담당자·사용자)의 삭제는 소프트 삭제이고, 이력이 있는 것은 삭제되지 않는다. Item Code·품목군 코드·창고 코드·위치 코드·사업자등록번호·로그인 ID는 삭제되지 않은 것끼리 겹치지 않는다 | DB (겹침) + TX (이력) | API 명세서 1.9절, NFR-15, `ux_products_item_code`·`ux_product_categories_code`·`ux_warehouses_warehouse_code`·`ux_locations_location_code`·`ux_partners_business_reg_no`·`ux_users_login_id` (2026-11-23) |
| INV-80 | 사용 중인 관리자 역할(`ADMIN`) 계정은 항상 한 명 이상이다. 누구도 자기 역할·사용 여부를 바꾸거나 자기 계정을 삭제할 수 없다. 계정의 역할·사용 여부·로그인 ID·비밀번호가 바뀌면 같은 트랜잭션에서 그 사람의 `tokens_valid_after`를 기록한다 | TX + 테스트 | API 명세서 1.3·1.9절, `USER_LAST_ADMIN`·`USER_SELF_CHANGE` (2026-11-23) |
| INV-81 | 검수 대기 배정(source_type RECEIVED)의 활성 합계 ≤ 자사 창고의 검수 대기 재고(제품별). 검수 대기 재고가 줄어 깨지면 처리를 막지 않고 같은 트랜잭션에서 나중에 만든 배정부터 자동 해제하고 알림(ALLOCATION_RELEASED)을 남긴다. INV-35(보유 배정 ≤ 정상 재고)는 STOCK 배정에만 적용한다 | TX + 점검 | 확정 사항 #88, 점검 C14 (2026-11-23) |
| INV-82 | 부대비용 유형이 대여료(RENTAL)이면 대차 문서가 연결되어 있고, 그 대차는 차입(IN)이다 | DB + TX | `ck_extra_costs_3`, 확정 사항 #93 (2026-11-23) |
| INV-83 | 단가·부대비용·대여료·초기 재고 단가가 바뀌면 같은 트랜잭션에서 cost_changes에 이전·새 값이 남는다. 금액과 금액 이력은 금액 보기 권한자에게만 응답한다(서버에서 필드를 빼고 보냄) | TX + 테스트 | 확정 사항 #91·#92 (2026-11-23) |
| INV-84 | 원화가 아닌 금액에는 환율 기준일이 있다 (단가·부대비용·대여료·초기 재고 단가) | DB | `ck_line_prices_2`, `ck_extra_costs_4`, `ck_loan_fees_2`, `ck_opening_costs_3`, 확정 사항 #94 (2026-11-23) |
| INV-85 | 귀속월이 마감된 금액(단가·부대비용·대여료·초기 재고 단가)은 바꾸거나 비울 수 없다. 비어 있는 단가를 처음 넣는 것만 허용. 귀속 기준이 MANUAL이면 귀속일이 있고, 아니면 없다 | TX + DB | 마감 행 잠금 아래 검사. `ck_line_prices_3·4` 등, 확정 사항 #103 (2026-11-23) |
| INV-86 | 첨부 파일의 내용(열기·내려받기)은 `COST_VIEW` 권한자에게만 나간다(2026-11-26 "관리자 또는"을 뺌: 관리자 역할은 금액 보기를 늘 가진다). 첨부 파일은 PDF·JPEG·PNG이고 20MB 이하이며, 올린 뒤 내용이 바뀌지 않는다(디스크 파일은 덮어쓰거나 지우지 않음). 첨부 하나는 디스크 파일 하나이고 다른 첨부와 파일을 공유하지 않는다 | DB (형식·크기·위치 키) + TX + 테스트 | 확정 사항 #104, `ck_files_2`·`ck_files_3`·`uq_files_storage_key`. 권한별 내려받기 API 테스트 (2026-11-24) |
| ~~INV-87~~ | ~~조회자 역할인 사용자는 금액 수정 권한을 갖지 않는다~~ → 2026-11-26 없앰(#106). 금액 쓰기 API는 영역 권한과 `COST_EDIT`을 함께 요구한다(권한 매트릭스 1.4) | — | 확정 사항 #105 → #106 |
| INV-88 | 관리자 역할(`ADMIN`)은 모든 권한을 갖고 바뀌거나 지워지지 않는다. `COST_EDIT`이 있는 역할은 `COST_VIEW`도 있다. 계정이 쓰고 있는 역할은 지워지지 않는다. DB의 권한 목록과 코드의 권한 목록은 같다 | TX + 테스트 | 확정 사항 #106, 권한 매트릭스 1.6, `ROLE_LOCKED`·`ROLE_COST_EDIT_WITHOUT_VIEW`·`ROLE_IN_USE` (2026-11-26) |

## 9. DDL 보강 제안 (v2·운영 최종본에 반영)

지금은 TX로만 막고 있지만 DB에서도 간단히 한 번 더 막을 수 있는 조건들이다. PostgreSQL 16 테스트 DB에 적용해 보니 위반은 차단되고 정상 처리는 통과했다 (2026-10-30). 부분 인덱스와 트리거라서 ERDCloud에는 나타나지 않는다. 2026-10-30 추후 수정용(v2)과 운영 최종본 DDL에 반영했고, 처음 생성용(v1)에는 넣지 않았다.

| 제안 | 막는 것 | 관련 |
|---|---|---|
| P1 | 같은 장비에 활성 배정이 2건 생기는 경우 (해제된 배정은 제외) | INV-24 |
| P2 | 시리얼 장비가 연결된 원장·납품·배정 줄의 수량이 1이 아닌 경우 | INV-19 |
| P3 | 원화인데 환율이 1이 아닌 금액 | INV-52 |
| P4 | 마감된 달의 업무 날짜로 원장 행을 추가하는 경우 | INV-15, INV-46 |
| P5 | 원장 행이 자기 자신을 취소하는 경우 | INV-11 |

```sql
-- P1 장비 1대에 활성 배정 1건
CREATE UNIQUE INDEX ux_allocations_active_equipment
    ON allocation.allocations (equipment_id)
    WHERE status = 'ACTIVE' AND equipment_id IS NOT NULL;

-- P2 시리얼 장비 줄은 수량 1
ALTER TABLE inventory.ledger_entries
    ADD CONSTRAINT ck_ledger_entries_equipment_unit CHECK (equipment_id IS NULL OR quantity_delta IN (1, -1));
ALTER TABLE delivery.delivery_lines
    ADD CONSTRAINT ck_delivery_lines_equipment_unit CHECK (equipment_id IS NULL OR quantity = 1);
ALTER TABLE allocation.allocations
    ADD CONSTRAINT ck_allocations_equipment_unit CHECK (equipment_id IS NULL OR quantity = 1);

-- P3 원화 금액은 환율 1
ALTER TABLE cost.line_prices ADD CONSTRAINT ck_line_prices_krw_rate CHECK (currency <> 'KRW' OR exchange_rate = 1);
ALTER TABLE cost.extra_costs ADD CONSTRAINT ck_extra_costs_krw_rate CHECK (currency <> 'KRW' OR exchange_rate = 1);
ALTER TABLE cost.loan_fees   ADD CONSTRAINT ck_loan_fees_krw_rate   CHECK (currency <> 'KRW' OR exchange_rate = 1);
ALTER TABLE cost.opening_costs ADD CONSTRAINT ck_opening_costs_krw_rate CHECK (currency <> 'KRW' OR exchange_rate = 1);

-- P4 마감된 달에는 원장 행 추가 금지
CREATE OR REPLACE FUNCTION inventory.fn_ledger_entries_closed_period()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    IF EXISTS (SELECT 1 FROM inventory.period_closings
               WHERE period = to_char(NEW.business_date, 'YYYY-MM') AND status = 'CLOSED') THEN
        RAISE EXCEPTION 'period % is closed', to_char(NEW.business_date, 'YYYY-MM');
    END IF;
    RETURN NEW;
END;
$$;
CREATE TRIGGER trg_ledger_entries_closed_period
    BEFORE INSERT ON inventory.ledger_entries
    FOR EACH ROW EXECUTE FUNCTION inventory.fn_ledger_entries_closed_period();

-- P5 자기 자신 취소 금지
ALTER TABLE inventory.ledger_entries
    ADD CONSTRAINT ck_ledger_entries_reversal_self CHECK (reversal_of_entry_id IS NULL OR reversal_of_entry_id <> id);
```

- P4만으로는 마감 처리와 원장 입력이 같은 순간에 겹치는 경우까지 막지 못한다. 마감 작업은 그달의 마감 행을 FOR UPDATE로 잠그고, 원장 입력 트랜잭션은 같은 행을 FOR SHARE로 읽어 순서를 보장한다.
- P2의 납품·배정 쪽 조건은 시리얼 장비를 한 줄에 1대씩 기록한다는 전제에서만 맞다. 반영하기 전에 테이블 정의서와 맞는지 다시 확인한다.

## 10. 정합성 점검 쿼리

- 매일 새벽과 월 마감 직전에 실행한다. 한 행이라도 나오면 관리자에게 알리고 마감을 진행하지 않는다. 결과는 `admin.integrity_check_results`에, 알림은 `admin.notifications`에 남긴다(INV-78, 2026-11-23).
- 모든 통합 테스트의 마지막에도 실행해 0행인지 확인한다.

```sql
-- C1 현재 재고 = 원장 합계 (INV-04)
WITH l AS (
    SELECT product_id, location_id, stock_condition, owner_type, owner_partner_id, SUM(quantity_delta) AS qty
    FROM inventory.ledger_entries
    GROUP BY product_id, location_id, stock_condition, owner_type, owner_partner_id
)
SELECT COALESCE(b.product_id, l.product_id) AS product_id,
       COALESCE(b.location_id, l.location_id) AS location_id,
       COALESCE(b.stock_condition, l.stock_condition) AS stock_condition,
       b.quantity AS balance_qty, l.qty AS ledger_qty
FROM inventory.stock_balances b
FULL JOIN l ON  l.product_id = b.product_id AND l.location_id = b.location_id
            AND l.stock_condition = b.stock_condition AND l.owner_type = b.owner_type
            AND l.owner_partner_id IS NOT DISTINCT FROM b.owner_partner_id
WHERE COALESCE(b.quantity, 0) <> COALESCE(l.qty, 0);

-- C2 시리얼 장비 원장 합계는 0 또는 1 (INV-19)
SELECT equipment_id, SUM(quantity_delta) AS qty
FROM inventory.ledger_entries
WHERE equipment_id IS NOT NULL
GROUP BY equipment_id
HAVING SUM(quantity_delta) NOT IN (0, 1);

-- C3 시리얼 장비가 두 곳 이상에 있는 경우 (INV-19)
SELECT equipment_id, COUNT(*) AS places
FROM (SELECT equipment_id, location_id, stock_condition, owner_type, owner_partner_id
      FROM inventory.ledger_entries WHERE equipment_id IS NOT NULL
      GROUP BY 1, 2, 3, 4, 5 HAVING SUM(quantity_delta) <> 0) t
GROUP BY equipment_id HAVING COUNT(*) > 1;

-- C4 쌍 처리의 수량 합은 0 (INV-09)
SELECT pair_id, SUM(quantity_delta) AS qty
FROM inventory.ledger_entries
WHERE pair_id IS NOT NULL
GROUP BY pair_id HAVING SUM(quantity_delta) <> 0;

-- C5 보유 재고 배정 합계 ≤ 자사 창고 정상 재고 (INV-35)
SELECT a.product_id, SUM(a.quantity - a.consumed_quantity) AS allocated, COALESCE(s.qty, 0) AS available
FROM allocation.allocations a
LEFT JOIN (SELECT b.product_id, SUM(b.quantity) AS qty
           FROM inventory.stock_balances b JOIN warehouse.locations loc ON loc.id = b.location_id
           WHERE b.stock_condition = 'AVAILABLE' AND loc.location_type = 'INTERNAL'
           GROUP BY b.product_id) s ON s.product_id = a.product_id
WHERE a.status = 'ACTIVE' AND a.source_type = 'STOCK'
GROUP BY a.product_id, s.qty
HAVING SUM(a.quantity - a.consumed_quantity) > COALESCE(s.qty, 0);

-- C6 기준일은 하나 (INV-58)
SELECT COUNT(DISTINCT business_date) AS opening_dates
FROM inventory.stock_transactions
WHERE transaction_type = 'OPENING' AND status = 'POSTED'
HAVING COUNT(DISTINCT business_date) > 1;

-- C7 기준일 이전 납품 장비의 납품일은 기준일 이전 (INV-56)
SELECT e.id, ev.business_date AS delivered_on
FROM equipment.equipment e
JOIN equipment.equipment_events ev ON ev.equipment_id = e.id AND ev.event_type = 'PRE_CUTOVER_DELIVERY'
WHERE e.origin_type = 'PRE_CUTOVER_DELIVERY'
  AND ev.business_date > (SELECT MIN(business_date) FROM inventory.stock_transactions
                          WHERE transaction_type = 'OPENING' AND status = 'POSTED');

-- C8 대여료 기록 위치 (INV-68)
SELECT 'extra_cost' AS kind, c.id
FROM cost.extra_costs c
LEFT JOIN loan.loan_documents d ON d.id = c.loan_document_id
WHERE c.cost_type = 'RENTAL' AND (d.id IS NULL OR d.direction <> 'IN')
UNION ALL
SELECT 'loan_fee', f.loan_document_id
FROM cost.loan_fees f
JOIN loan.loan_documents d ON d.id = f.loan_document_id
WHERE d.direction <> 'OUT';

-- C9 거래 품목의 처리된 수량 = 원본 기록 합계 (INV-75)
--   매입·선발주: 입고·공급사 반품·오류 조정(그 취소·정정 포함)의 원장 수량 + 직납 수량
--   매출: 납품 수량 − 반품 수량
--   대차 전환으로 만든 문서: 그 대차 문서의 확정된 전환 정산 기록 수량 합계 (실제 제품별)
WITH lt AS (
    SELECT e.trade_line_id AS line_id, e.quantity_delta,
           CASE WHEN t.transaction_type IN ('REVERSAL', 'CORRECTION') THEN o.transaction_type
                ELSE t.transaction_type END AS eff_type
    FROM inventory.ledger_entries e
    JOIN inventory.stock_transactions t ON t.id = e.transaction_id AND t.status = 'POSTED'
    LEFT JOIN inventory.stock_transactions o ON o.id = t.related_transaction_id
    WHERE e.trade_line_id IS NOT NULL
), conv AS (
    SELECT converted_trade_document_id AS doc_id, id AS loan_id
    FROM loan.loan_documents WHERE converted_trade_document_id IS NOT NULL
), expected AS (
    SELECT l.id AS line_id,
           CASE WHEN d.trade_type IN ('PURCHASE', 'PRE_ORDER') THEN
                COALESCE((SELECT SUM(lt.quantity_delta) FROM lt
                          WHERE lt.line_id = l.id
                            AND lt.eff_type IN ('RECEIPT', 'SUPPLIER_RETURN', 'ADJUSTMENT')), 0)
              + COALESCE((SELECT SUM(dl.quantity) FROM delivery.delivery_lines dl
                          JOIN delivery.deliveries dv ON dv.id = dl.delivery_id AND dv.status = 'POSTED'
                          WHERE dl.purchase_line_id = l.id), 0)
           ELSE
                COALESCE((SELECT SUM(dl.quantity - dl.returned_quantity) FROM delivery.delivery_lines dl
                          JOIN delivery.deliveries dv ON dv.id = dl.delivery_id AND dv.status = 'POSTED'
                          WHERE dl.sales_line_id = l.id), 0)
           END AS qty
    FROM project.trade_lines l
    JOIN project.trade_documents d ON d.id = l.document_id
    WHERE d.id NOT IN (SELECT doc_id FROM conv)
)
SELECT 'trade_line' AS kind, l.id AS ref_id, l.product_id, l.fulfilled_quantity AS stored, x.qty AS expected
FROM project.trade_lines l JOIN expected x ON x.line_id = l.id
WHERE l.fulfilled_quantity <> x.qty
UNION ALL
SELECT 'converted_document', c.doc_id, s.product_id, s.stored, COALESCE(g.qty, 0)
FROM conv c
JOIN (SELECT document_id, product_id, SUM(fulfilled_quantity) AS stored
      FROM project.trade_lines GROUP BY document_id, product_id) s ON s.document_id = c.doc_id
LEFT JOIN (SELECT ll.loan_id, st.settled_product_id AS product_id, SUM(st.quantity) AS qty
           FROM loan.loan_settlements st JOIN loan.loan_lines ll ON ll.id = st.loan_line_id
           WHERE st.method = 'CONVERT' AND st.status = 'POSTED'
           GROUP BY 1, 2) g ON g.loan_id = c.loan_id AND g.product_id = s.product_id
WHERE s.stored <> COALESCE(g.qty, 0);

-- C10 배정 소진 수량 = 소진 이력 합계, 상태와 수량이 맞음 (INV-75)
--   출고 취소로 소진이 되돌아가면 CONSUME 이력을 음수 수량으로 남긴다
SELECT a.id, a.status, a.quantity, a.consumed_quantity,
       COALESCE(SUM(ev.quantity) FILTER (WHERE ev.action = 'CONSUME'), 0) AS consumed_by_events
FROM allocation.allocations a
LEFT JOIN allocation.allocation_events ev ON ev.allocation_id = a.id
GROUP BY a.id, a.status, a.quantity, a.consumed_quantity
HAVING a.consumed_quantity <> COALESCE(SUM(ev.quantity) FILTER (WHERE ev.action = 'CONSUME'), 0)
    OR (a.status = 'CONSUMED' AND a.consumed_quantity <> a.quantity)
    OR (a.status = 'ACTIVE' AND a.consumed_quantity >= a.quantity);

-- C11 납품 품목의 반품 수량 = 확정되고 취소되지 않은 반품 기록 합계 (INV-75)
--   반품 취소는 반품 입고 묶음 단위로 한다
SELECT dl.id, dl.returned_quantity, COALESCE(r.qty, 0) AS returned_by_records
FROM delivery.delivery_lines dl
LEFT JOIN (
    SELECT r.delivery_line_id, SUM(r.quantity) AS qty
    FROM delivery.delivery_returns r
    JOIN inventory.stock_transactions t ON t.id = r.transaction_id AND t.status = 'POSTED'
    WHERE r.delivery_line_id IS NOT NULL
      AND NOT EXISTS (SELECT 1 FROM inventory.stock_transactions x
                      WHERE x.related_transaction_id = t.id AND x.status = 'POSTED'
                        AND x.transaction_type IN ('REVERSAL', 'CORRECTION'))
    GROUP BY r.delivery_line_id) r ON r.delivery_line_id = dl.id
WHERE dl.returned_quantity <> COALESCE(r.qty, 0);

-- C12 장비 상태·현재 위치·소유 = 원장 위치 (INV-20)
WITH pos AS (
    SELECT e.equipment_id, e.location_id, e.stock_condition, e.owner_type, e.owner_partner_id,
           SUM(e.quantity_delta) AS qty
    FROM inventory.ledger_entries e
    JOIN inventory.stock_transactions t ON t.id = e.transaction_id AND t.status = 'POSTED'
    WHERE e.equipment_id IS NOT NULL
    GROUP BY 1, 2, 3, 4, 5 HAVING SUM(e.quantity_delta) <> 0
), expect AS (
    SELECT q.id, q.status, q.current_location_id, q.owner_type, q.owner_partner_id,
           CASE q.status WHEN 'IN_STOCK'       THEN 'INTERNAL/AVAILABLE'
                         WHEN 'INSPECTION'     THEN 'INTERNAL/INSPECTION'
                         WHEN 'DEFECTIVE'      THEN 'INTERNAL/DEFECTIVE'
                         WHEN 'IN_REPAIR'      THEN 'REPAIR/IN_REPAIR'
                         WHEN 'LOANED_OUT'     THEN 'LOAN_OUT/*'
                         WHEN 'TEMP_INSTALLED' THEN 'CUSTOMER_SITE/*'
                         ELSE 'NONE' END AS place
    FROM equipment.equipment q
)
SELECT x.id, x.status, x.place, loc.location_type, p.stock_condition, p.qty
FROM expect x
LEFT JOIN pos p ON p.equipment_id = x.id
LEFT JOIN warehouse.locations loc ON loc.id = p.location_id
WHERE (x.place = 'NONE' AND p.equipment_id IS NOT NULL)
   OR (x.place <> 'NONE' AND (p.equipment_id IS NULL OR p.qty <> 1
        OR loc.location_type <> split_part(x.place, '/', 1)
        OR (split_part(x.place, '/', 2) <> '*' AND p.stock_condition <> split_part(x.place, '/', 2))
        OR p.location_id IS DISTINCT FROM x.current_location_id
        OR p.owner_type <> x.owner_type
        OR p.owner_partner_id IS DISTINCT FROM x.owner_partner_id));

-- C13 대차 품목의 정산 수량 = 확정된 정산 기록 합계 (INV-76)
SELECT ll.id, ll.settled_quantity,
       COALESCE(SUM(st.quantity) FILTER (WHERE st.status = 'POSTED'), 0) AS settled_by_records
FROM loan.loan_lines ll
LEFT JOIN loan.loan_settlements st ON st.loan_line_id = ll.id
GROUP BY ll.id, ll.settled_quantity
HAVING ll.settled_quantity <> COALESCE(SUM(st.quantity) FILTER (WHERE st.status = 'POSTED'), 0);

-- C14 검수 대기 배정 합계 ≤ 자사 창고 검수 대기 재고, 제품별 (INV-81)
WITH r AS (
    SELECT product_id, SUM(quantity - consumed_quantity) AS q
    FROM allocation.allocations
    WHERE status = 'ACTIVE' AND source_type = 'RECEIVED'
    GROUP BY product_id
), i AS (
    SELECT b.product_id, SUM(b.quantity) AS q
    FROM inventory.stock_balances b
    JOIN warehouse.locations l ON l.id = b.location_id
    WHERE l.location_type = 'INTERNAL' AND b.stock_condition = 'INSPECTION'
    GROUP BY b.product_id
)
SELECT r.product_id, r.q AS received_allocated, COALESCE(i.q, 0) AS inspection_stock
FROM r LEFT JOIN i ON i.product_id = r.product_id
WHERE r.q > COALESCE(i.q, 0);

-- C15 대차 품목: 정산 수량 ≤ 받은·내보낸 수량 (#89)
SELECT id, moved_quantity, settled_quantity
FROM loan.loan_lines
WHERE settled_quantity > moved_quantity;
```

테스트 DB에서 현재 재고 갱신을 일부러 빠뜨려 보니 C1이 이를 잡아냈다. C9–C12는 2026-11-09에 추가했다. 시험 데이터(입고·공급사 반품·입고 취소·창고 출고·직납·고객 반품·수리 출고·배정 소진과 되돌림·대차 전환)에서는 0행이었고, 처리 수량·전환 문서 수량·소진 수량·반품 수량·반품 취소·장비 상태·장비 현재 위치를 하나씩 일부러 틀어 놓은 7가지 경우를 모두 잡아냈다. INV-47(마감 스냅샷)의 점검 쿼리는 스냅샷 생성 방식이 확정되면 추가한다. 2026-11-23 대차 정산 기록(`loan_settlements`)을 추가하면서 C9의 전환 문서 부분을 정산 기록 기준으로 바꾸고 C13을 추가했다. 시험 데이터는 0행이었고, 기존 7가지에 대차 정산 수량과 정산 기록 반려를 더한 9가지 경우를 모두 잡아냈다.

## 11. 테스트 작성 규칙

| 강제 위치 | 테스트 방법 |
|---|---|
| DB | Testcontainers PostgreSQL에서 위반하는 SQL을 직접 실행해 예외가 나는지 확인 |
| TX | 서비스를 호출해 위반을 시도하고, 정해진 에러 코드가 나오면서 원장·현재 재고·배정이 그대로인지 확인 |
| 동시성 (INV-03, INV-24, INV-35) | 여러 스레드로 같은 요청을 동시에 보내 한 건만 확정되는지 확인 (AT-06, AT-10) |
| ARCH | ModularityTest의 `modules.verify()` |
| 점검 | 통합 테스트 공통 후처리에서 C1–C15를 실행해 0행인지 확인 |

- 테스트 이름 앞에 ID를 붙인다. 예: `INV03_동시_출고_시_음수_재고_불가`
- 새 규칙을 확정하면 이 목록에 ID를 추가하고, 강제 위치와 테스트를 함께 정한다.
