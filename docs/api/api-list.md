# API 목록 (색인)

> 원본(노션): https://app.notion.com/p/421b82ca31e581898e3fe58ea8d40ecb (API 목록 데이터베이스)  
> 내보낸 날짜: 2026-11-24. **노션이 원본이다.** 각 API의 요청·응답·오류·바뀌는 것은 "노션" 열의 행 페이지에 있다.

API 151개. 권한 열은 [권한 매트릭스](../rules/permissions.md) 1.1절의 조건 표기다. 금액 = 응답·요청에 금액 필드가 있음(권한 없으면 필드를 뺌). 키 = `Idempotency-Key` 필수(API 명세서 1.5).

> ⚠️ 확정 전인 행: 제품 수정. 이력 있는 제품의 시리얼 관리 여부 변경을 일단 막아 둔 상태다(`PRODUCT_SERIAL_LOCKED`, 가이드 A3). 행에 적힌 대로 구현하면 된다.


## 1단계 (43개)

| 모듈 | API | 메서드 | 경로 | 권한 | 금액 | 키 | 관련 INV | 노션 |
|---|---|---|---|---|---|---|---|---|
| cost | 통화 목록 | GET | `/api/v1/cost/currency` | 모두 |  |  |  | [열기](https://app.notion.com/p/421b82ca31e581319c6af94efb6c80a4) |
| cost | 통화 추가 | POST | `/api/v1/cost/currency` | 관리자 |  |  |  | [열기](https://app.notion.com/p/421b82ca31e5814eac28c515d8557d38) |
| cost | 통화 수정 (이름·켜기·끄기) | PATCH | `/api/v1/cost/currency/{code}` | 관리자 |  |  |  | [열기](https://app.notion.com/p/421b82ca31e5812b862fdce833d06dcc) |
| partner | 거래처 목록 | GET | `/api/v1/partner` | 모두 |  |  |  | [열기](https://app.notion.com/p/421b82ca31e581d0b0cfed044585962f) |
| partner | 거래처 등록 (구분·담당자 함께) | POST | `/api/v1/partner` | 입력 |  |  |  | [열기](https://app.notion.com/p/421b82ca31e58116be08e12aea345309) |
| partner | 담당자 수정 | PATCH | `/api/v1/partner/contact/{id}` | 입력 |  |  |  | [열기](https://app.notion.com/p/421b82ca31e581e0806ee08cc34e90de) |
| partner | 담당자 삭제 | DELETE | `/api/v1/partner/contact/{id}` | 입력 |  |  |  | [열기](https://app.notion.com/p/421b82ca31e581dea469f667a470429d) |
| partner | 거래처 하나 (담당자 포함) | GET | `/api/v1/partner/{id}` | 모두 |  |  |  | [열기](https://app.notion.com/p/421b82ca31e58197abe2dea4b504587d) |
| partner | 거래처 수정 (구분 포함) | PATCH | `/api/v1/partner/{id}` | 입력 |  |  |  | [열기](https://app.notion.com/p/421b82ca31e5811c98c8cd5c79a489f0) |
| partner | 거래처 삭제 | DELETE | `/api/v1/partner/{id}` | 입력 |  |  |  | [열기](https://app.notion.com/p/421b82ca31e5818aa05aeef51dcbb480) |
| partner | 담당자 추가 | POST | `/api/v1/partner/{id}/contact` | 입력 |  |  |  | [열기](https://app.notion.com/p/421b82ca31e58172a4fcfed371073aef) |
| product | 제품 목록 | GET | `/api/v1/product` | 모두 |  |  |  | [열기](https://app.notion.com/p/421b82ca31e5815281c6ea56861a7f22) |
| product | 제품 등록 | POST | `/api/v1/product` | 입력 |  |  |  | [열기](https://app.notion.com/p/421b82ca31e581bfb5b5ca6688e79ff0) |
| product | 품목군 목록 | GET | `/api/v1/product/category` | 모두 |  |  |  | [열기](https://app.notion.com/p/421b82ca31e58171a1d3f727dbee00d7) |
| product | 품목군 추가 | POST | `/api/v1/product/category` | 관리자 |  |  |  | [열기](https://app.notion.com/p/421b82ca31e581f4a07ef2a60c9103cf) |
| product | 품목군 수정 (이름·순서·사용 여부) | PATCH | `/api/v1/product/category/{id}` | 관리자 |  |  |  | [열기](https://app.notion.com/p/421b82ca31e581338cefd75249c8cf47) |
| product | 품목군 삭제 | DELETE | `/api/v1/product/category/{id}` | 관리자 |  |  |  | [열기](https://app.notion.com/p/421b82ca31e5812297c1cc28b322b7c6) |
| product | 제품 하나 | GET | `/api/v1/product/{id}` | 모두 |  |  |  | [열기](https://app.notion.com/p/421b82ca31e58117ac44fab5619de40e) |
| product | 제품 수정 ⚠️확정 전 | PATCH | `/api/v1/product/{id}` | 입력 |  |  | INV-72 | [열기](https://app.notion.com/p/421b82ca31e581539055ff7c030b7cd4) |
| product | 제품 삭제 | DELETE | `/api/v1/product/{id}` | 입력 |  |  | INV-71 | [열기](https://app.notion.com/p/421b82ca31e5819ca427df70027d6b01) |
| product | 제품 다시 사용 | POST | `/api/v1/product/{id}/activate` | 관리자 |  |  | INV-72 | [열기](https://app.notion.com/p/421b82ca31e58175aa28c80640d9f1a7) |
| product | 제품 변경 이력 | GET | `/api/v1/product/{id}/change` | 관리자 |  |  |  | [열기](https://app.notion.com/p/421b82ca31e581a083e1f7da9d5c95b2) |
| product | 제품 사용 중지 | POST | `/api/v1/product/{id}/deactivate` | 관리자 |  |  | INV-70, INV-71, INV-72 | [열기](https://app.notion.com/p/421b82ca31e5811298b9cae9e543895b) |
| user | 사용자 목록 | GET | `/api/v1/user` | 관리자 |  |  |  | [열기](https://app.notion.com/p/421b82ca31e5814f9187cbe31feb571b) |
| user | 계정 만들기 | POST | `/api/v1/user` | 관리자 |  |  |  | [열기](https://app.notion.com/p/421b82ca31e5810f9f5ce2173c86476a) |
| user | 내 정보 | GET | `/api/v1/user/me` | 모두 |  |  |  | [열기](https://app.notion.com/p/421b82ca31e581f5a9dde4ac17f79776) |
| user | 본인 비밀번호 변경 | POST | `/api/v1/user/me/password` | 모두 |  |  |  | [열기](https://app.notion.com/p/421b82ca31e581c4987cdfe99e58da44) |
| user | 역할 목록 | GET | `/api/v1/user/role` | 관리자 |  |  |  | [열기](https://app.notion.com/p/421b82ca31e581eda913d6ec29659923) |
| user | 사용자 하나 | GET | `/api/v1/user/{id}` | 관리자 |  |  |  | [열기](https://app.notion.com/p/421b82ca31e5818a92e4d674f278dcda) |
| user | 계정 수정 (역할·금액 권한·사용 여부 포함) | PATCH | `/api/v1/user/{id}` | 관리자 |  |  |  | [열기](https://app.notion.com/p/421b82ca31e5810db1ebd8793e79eb2c) |
| user | 계정 삭제 | DELETE | `/api/v1/user/{id}` | 관리자 |  |  |  | [열기](https://app.notion.com/p/421b82ca31e581daba0fd798a319516a) |
| user | 비밀번호 초기화 | POST | `/api/v1/user/{id}/password-reset` | 관리자 |  |  |  | [열기](https://app.notion.com/p/421b82ca31e58186aca5c2a5534654a2) |
| user | 로그인·로그아웃 | POST | `/api/v1/user/login, /api/v1/user/logout` | 모두 |  |  |  | [열기](https://app.notion.com/p/421b82ca31e5811c9b4bf2988866f304) |
| warehouse | 창고 목록 | GET | `/api/v1/warehouse` | 모두 |  |  |  | [열기](https://app.notion.com/p/421b82ca31e581a8bbfbc7e2d036084d) |
| warehouse | 창고 등록 | POST | `/api/v1/warehouse` | 관리자 |  |  |  | [열기](https://app.notion.com/p/421b82ca31e5819185c8f27f835b468c) |
| warehouse | 위치 목록 | GET | `/api/v1/warehouse/location` | 모두 |  |  |  | [열기](https://app.notion.com/p/421b82ca31e5815391f9e090560c08c7) |
| warehouse | 위치 등록 | POST | `/api/v1/warehouse/location` | 관리자 |  |  |  | [열기](https://app.notion.com/p/421b82ca31e5813d8937fc4d149a2c4e) |
| warehouse | 위치 하나 | GET | `/api/v1/warehouse/location/{id}` | 모두 |  |  |  | [열기](https://app.notion.com/p/421b82ca31e581118220e918d73f0271) |
| warehouse | 위치 수정 | PATCH | `/api/v1/warehouse/location/{id}` | 관리자 |  |  |  | [열기](https://app.notion.com/p/421b82ca31e581feba10c61fda87f526) |
| warehouse | 위치 삭제 | DELETE | `/api/v1/warehouse/location/{id}` | 관리자 |  |  |  | [열기](https://app.notion.com/p/421b82ca31e581749572c392075524d7) |
| warehouse | 창고 하나 | GET | `/api/v1/warehouse/{id}` | 모두 |  |  |  | [열기](https://app.notion.com/p/421b82ca31e5818b8b34ead618857a12) |
| warehouse | 창고 수정 | PATCH | `/api/v1/warehouse/{id}` | 관리자 |  |  |  | [열기](https://app.notion.com/p/421b82ca31e5811ba5f6daab90fe27c8) |
| warehouse | 창고 삭제 | DELETE | `/api/v1/warehouse/{id}` | 관리자 |  |  |  | [열기](https://app.notion.com/p/421b82ca31e581c494f0cdc060de62d0) |

## 2단계 (46개)

| 모듈 | API | 메서드 | 경로 | 권한 | 금액 | 키 | 관련 INV | 노션 |
|---|---|---|---|---|---|---|---|---|
| admin | 정합성 점검 결과 목록 | GET | `/api/v1/admin/integrity-check` | 관리자 |  |  | INV-78 | [열기](https://app.notion.com/p/421b82ca31e58192ad6edb7066e78e0f) |
| admin | 정합성 점검 지금 실행 | POST | `/api/v1/admin/integrity-check/run` | 관리자 |  |  | INV-78 | [열기](https://app.notion.com/p/421b82ca31e581ac8236c41f39c1754e) |
| admin | 내 알림 목록 | GET | `/api/v1/admin/notification` | 모두 |  |  |  | [열기](https://app.notion.com/p/421b82ca31e581c3ac9cfeb7dac53cc4) |
| admin | 알림 읽음 표시 | POST | `/api/v1/admin/notification/read` | 모두 |  |  |  | [열기](https://app.notion.com/p/421b82ca31e581298181f48b93204922) |
| admin | 승인·확인 대기함 목록 | GET | `/api/v1/admin/review` | 입력 |  |  |  | [열기](https://app.notion.com/p/421b82ca31e5810b8eb9d82dee799cdf) |
| admin | 승인·확인 요청 하나 | GET | `/api/v1/admin/review/{id}` | 입력 |  |  |  | [열기](https://app.notion.com/p/421b82ca31e58194a3dad8e4a0f4d7be) |
| admin | 승인 | POST | `/api/v1/admin/review/{id}/approve` | 관리자 |  | ✓ | INV-77 | [열기](https://app.notion.com/p/421b82ca31e5813eb0ccf31711b71e1c) |
| admin | 확인 (사후 확인) | POST | `/api/v1/admin/review/{id}/confirm` | 관리자 |  |  |  | [열기](https://app.notion.com/p/421b82ca31e581b0be96ca4aaaf1ba67) |
| admin | 반려 | POST | `/api/v1/admin/review/{id}/reject` | 관리자 |  | ✓ | INV-77 | [열기](https://app.notion.com/p/421b82ca31e58105a0b7e4b47ba15c4c) |
| delivery | 창고 출고 | POST | `/api/v1/delivery/issue` | 입력 |  | ✓ | INV-03, INV-35, INV-40 | [열기](https://app.notion.com/p/421b82ca31e58111ac4be64270d6c240) |
| delivery | 발주 입고 (시리얼·부분 입고 포함) | POST | `/api/v1/delivery/receipt` | 입력 |  | ✓ | INV-17, INV-26, INV-27, INV-28 | [열기](https://app.notion.com/p/421b82ca31e5812e8d9ed05f9dae4448) |
| equipment | 장비 목록 (시리얼 찾기) | GET | `/api/v1/equipment` | 모두 |  |  |  | [열기](https://app.notion.com/p/421b82ca31e58190abdbf1112f5b48df) |
| equipment | 기준일 전 납품 장비 등록 | POST | `/api/v1/equipment/pre-cutover-delivery` | 관리자 |  | ✓ |  | [열기](https://app.notion.com/p/421b82ca31e581149965e7f715074ffc) |
| equipment | 장비 하나 (이력 포함) | GET | `/api/v1/equipment/{id}` | 모두 |  |  |  | [열기](https://app.notion.com/p/421b82ca31e5811bb99ce89ed8cf52fa) |
| equipment | 장비 시리얼·메모 수정 | PATCH | `/api/v1/equipment/{id}` | 입력 |  |  | INV-17 | [열기](https://app.notion.com/p/421b82ca31e581a8a69af8cfea884055) |
| inventory | 재고 조정 (이번 달 조정) | POST | `/api/v1/inventory/adjustment` | 관리자 |  | ✓ |  | [열기](https://app.notion.com/p/421b82ca31e581bb999cf3743045cb49) |
| inventory | 검수 판정 | POST | `/api/v1/inventory/inspection-result` | 입력 |  | ✓ |  | [열기](https://app.notion.com/p/421b82ca31e581d1a8e4f44cb6f2ff12) |
| inventory | 초기 재고 넣기 | POST | `/api/v1/inventory/opening` | 관리자 |  | ✓ | INV-58, INV-60 | [열기](https://app.notion.com/p/421b82ca31e58137aedee31705e33b4b) |
| inventory | 월 마감 목록 | GET | `/api/v1/inventory/period-closing` | 모두 |  |  |  | [열기](https://app.notion.com/p/421b82ca31e581aaa06bfc1f65a8d51b) |
| inventory | 월 마감 하기 | POST | `/api/v1/inventory/period-closing/{period}/close` | 관리자 |  | ✓ | INV-46, INV-78 | [열기](https://app.notion.com/p/421b82ca31e581c5b5a4e40838092c76) |
| inventory | 월 마감 해제 | POST | `/api/v1/inventory/period-closing/{period}/reopen` | 관리자 |  | ✓ |  | [열기](https://app.notion.com/p/421b82ca31e58188bea5cb6acbc03fb3) |
| inventory | 재고 목록 | GET | `/api/v1/inventory/stock` | 모두 |  |  | INV-01, INV-02 | [열기](https://app.notion.com/p/421b82ca31e581139e11d95d3ff22c03) |
| inventory | 실사 목록 | GET | `/api/v1/inventory/stock-count` | 모두 |  |  |  | [열기](https://app.notion.com/p/421b82ca31e581f586e9e44a7609cc93) |
| inventory | 실사 준비 (만들기) | POST | `/api/v1/inventory/stock-count` | 입력 |  |  |  | [열기](https://app.notion.com/p/421b82ca31e5814b9b87c12554bd950b) |
| inventory | 실사 하나 (줄·시리얼 포함) | GET | `/api/v1/inventory/stock-count/{id}` | 모두 |  |  |  | [열기](https://app.notion.com/p/421b82ca31e5811493d7feb02bbd04c8) |
| inventory | 실사 취소 | POST | `/api/v1/inventory/stock-count/{id}/cancel` | 입력 |  |  |  | [열기](https://app.notion.com/p/421b82ca31e581069ab5f9804e03bd5d) |
| inventory | 실사 수량 입력 | PATCH | `/api/v1/inventory/stock-count/{id}/line` | 입력 |  |  |  | [열기](https://app.notion.com/p/421b82ca31e581efa51ae563863ec0b0) |
| inventory | 실사 시작 (잠금) | POST | `/api/v1/inventory/stock-count/{id}/start` | 입력 |  | ✓ | INV-48 | [열기](https://app.notion.com/p/421b82ca31e581078c45f5d90f3ede5b) |
| inventory | 실사 제출 | POST | `/api/v1/inventory/stock-count/{id}/submit` | 입력 |  | ✓ |  | [열기](https://app.notion.com/p/421b82ca31e581fe894edaeb07585868) |
| inventory | 처리 묶음 목록 (처리 이력) | GET | `/api/v1/inventory/stock-transaction` | 모두 |  |  |  | [열기](https://app.notion.com/p/421b82ca31e5814bbb63dd560a67dd26) |
| inventory | 처리 묶음 하나 (줄 포함) | GET | `/api/v1/inventory/stock-transaction/{id}` | 모두 |  |  |  | [열기](https://app.notion.com/p/421b82ca31e581659081f3d08b8d1eda) |
| inventory | 처리 정정 (취소 + 다시 입력) | POST | `/api/v1/inventory/stock-transaction/{id}/correction` | 입력 |  | ✓ | INV-10, INV-11 | [열기](https://app.notion.com/p/421b82ca31e581b1a129d48fd320779e) |
| inventory | 처리 취소 | POST | `/api/v1/inventory/stock-transaction/{id}/reversal` | 입력 |  | ✓ | INV-10, INV-11, INV-12 | [열기](https://app.notion.com/p/421b82ca31e581ccb512dd0c88ef126c) |
| inventory | 위치 옮기기 | POST | `/api/v1/inventory/transfer` | 입력 |  | ✓ | INV-03, INV-35, INV-48 | [열기](https://app.notion.com/p/421b82ca31e5810a8305df31610eabf9) |
| inventory | 발주 없이 입고 (비정상 입고) | POST | `/api/v1/inventory/unplanned-receipt` | 입력 |  | ✓ | INV-77 | [열기](https://app.notion.com/p/421b82ca31e581108c75fb33ccf50fba) |
| project | 프로젝트 목록 | GET | `/api/v1/project` | 모두 |  |  |  | [열기](https://app.notion.com/p/421b82ca31e58173b92dec331201910a) |
| project | 프로젝트 만들기 | POST | `/api/v1/project` | 입력 |  |  |  | [열기](https://app.notion.com/p/421b82ca31e58101af6ef5116ba4774b) |
| project | 거래 문서 목록 | GET | `/api/v1/project/trade-document` | 모두 | ✓ |  |  | [열기](https://app.notion.com/p/421b82ca31e5813c92fcfe3d74a402eb) |
| project | 거래 문서 등록 (품목 포함) | POST | `/api/v1/project/trade-document` | 입력 |  |  | INV-31, INV-70 | [열기](https://app.notion.com/p/421b82ca31e5810e8e00fe3a695be147) |
| project | 거래 문서 하나 (품목·잔량 포함) | GET | `/api/v1/project/trade-document/{id}` | 모두 | ✓ |  |  | [열기](https://app.notion.com/p/421b82ca31e581558cb4ccff6c6c7315) |
| project | 거래 문서 수정 | PATCH | `/api/v1/project/trade-document/{id}` | 입력 |  |  | INV-55 | [열기](https://app.notion.com/p/421b82ca31e5817f8dbde2189d324cb4) |
| project | 거래 문서 삭제 | DELETE | `/api/v1/project/trade-document/{id}` | 입력 |  |  |  | [열기](https://app.notion.com/p/421b82ca31e581568b52fbd2dca1b6a3) |
| project | 거래 문서 확정 | POST | `/api/v1/project/trade-document/{id}/confirm` | 입력 |  | ✓ |  | [열기](https://app.notion.com/p/421b82ca31e5816d8ce4dd96de2462a8) |
| project | 프로젝트 하나 | GET | `/api/v1/project/{id}` | 모두 |  |  |  | [열기](https://app.notion.com/p/421b82ca31e5818e891dca89ac6c50c6) |
| project | 프로젝트 수정 (이름·고객사·상태) | PATCH | `/api/v1/project/{id}` | 입력 |  |  | INV-65, INV-66 | [열기](https://app.notion.com/p/421b82ca31e58165a80ff7cd0803bb4e) |
| project | 프로젝트 삭제 | DELETE | `/api/v1/project/{id}` | 입력 |  |  | INV-65, INV-66 | [열기](https://app.notion.com/p/421b82ca31e58133810ecafeadf970e7) |

## 3단계 (43개)

| 모듈 | API | 메서드 | 경로 | 권한 | 금액 | 키 | 관련 INV | 노션 |
|---|---|---|---|---|---|---|---|---|
| admin | 변경 이력 조회 (통합) | GET | `/api/v1/admin/change-history` | 관리자 |  |  |  | [열기](https://app.notion.com/p/421b82ca31e581b5b05ffd2fa61314b6) |
| allocation | 배정 목록 (프로젝트 배정 현황) | GET | `/api/v1/allocation` | 모두 |  |  |  | [열기](https://app.notion.com/p/421b82ca31e58158918ced8bf7e4d1a3) |
| allocation | 보유 재고 배정 (수량·장비) | POST | `/api/v1/allocation` | 입력 |  | ✓ | INV-35, INV-38 | [열기](https://app.notion.com/p/421b82ca31e581cebaa3e872d1df1c9f) |
| allocation | 배정 가능 수량·장비 조회 | GET | `/api/v1/allocation/available` | 모두 |  |  | INV-35 | [열기](https://app.notion.com/p/421b82ca31e58111bd30c173d0547661) |
| allocation | 발주 예정 물량 배정 | POST | `/api/v1/allocation/planned` | 입력 |  | ✓ | INV-38, INV-81 | [열기](https://app.notion.com/p/421b82ca31e5815a843beea4722faac9) |
| allocation | 배정 하나 (이력 포함) | GET | `/api/v1/allocation/{id}` | 모두 |  |  |  | [열기](https://app.notion.com/p/421b82ca31e581d6a772f9432f5ac29e) |
| allocation | 배정 수량 바꾸기 | PATCH | `/api/v1/allocation/{id}` | 입력 |  | ✓ | INV-35, INV-37 | [열기](https://app.notion.com/p/421b82ca31e581e5bcdffc91f3b8859b) |
| allocation | 배정 다른 프로젝트로 옮기기 | POST | `/api/v1/allocation/{id}/move` | 입력 |  | ✓ |  | [열기](https://app.notion.com/p/421b82ca31e5810c9682d9dddd2693ab) |
| allocation | 배정 해제 | POST | `/api/v1/allocation/{id}/release` | 입력 |  | ✓ |  | [열기](https://app.notion.com/p/421b82ca31e581b9be54cff9fb0f3c9a) |
| delivery | 납품 현황 (회차 목록) | GET | `/api/v1/delivery` | 모두 |  |  |  | [열기](https://app.notion.com/p/421b82ca31e581f4b0f2c4ffdcc6bcbc) |
| delivery | 구성 묶음 납품 (세트 출고) | POST | `/api/v1/delivery/bundle` | 입력 |  | ✓ | INV-07, INV-35 | [열기](https://app.notion.com/p/421b82ca31e581628bd9d1f0f9bfccb2) |
| delivery | 고객 반품 받기 | POST | `/api/v1/delivery/customer-return` | 입력 |  | ✓ |  | [열기](https://app.notion.com/p/421b82ca31e581469f12db808f5ef068) |
| delivery | 현장 직납 기록 (차입 직납 포함) | POST | `/api/v1/delivery/direct` | 입력 |  | ✓ | INV-26, INV-40 | [열기](https://app.notion.com/p/421b82ca31e5811abf2ff7e3dd61fd16) |
| delivery | 교체해 주기 (회수 + 대체품 출고) | POST | `/api/v1/delivery/exchange` | 입력 |  | ✓ | INV-07 | [열기](https://app.notion.com/p/421b82ca31e5818db327ffd30ada0fa6) |
| delivery | 공급사에 반품 | POST | `/api/v1/delivery/supplier-return` | 입력 |  | ✓ |  | [열기](https://app.notion.com/p/421b82ca31e581ad8214ca79e0898d53) |
| delivery | 납품 회차 하나 | GET | `/api/v1/delivery/{id}` | 모두 |  |  |  | [열기](https://app.notion.com/p/421b82ca31e581dea3bdc98a3f3e072e) |
| equipment | 현장 수리 기록 | POST | `/api/v1/equipment/{id}/field-repair` | 입력 |  |  |  | [열기](https://app.notion.com/p/421b82ca31e581c9970de60cb6399111) |
| inventory | 폐기 요청 | POST | `/api/v1/inventory/disposal` | 입력 |  | ✓ | INV-77 | [열기](https://app.notion.com/p/421b82ca31e5813cadfdff45a160fa40) |
| inventory | 수리 받기 (다른 시리얼 포함) | POST | `/api/v1/inventory/repair-in` | 입력 |  | ✓ |  | [열기](https://app.notion.com/p/421b82ca31e581119c90e765e4a4a566) |
| inventory | 수리 보내기 | POST | `/api/v1/inventory/repair-out` | 입력 |  | ✓ |  | [열기](https://app.notion.com/p/421b82ca31e581a891ead2f9411a2435) |
| loan | 대차 문서 목록 (기한 지난 목록 포함) | GET | `/api/v1/loan` | 모두 |  |  |  | [열기](https://app.notion.com/p/421b82ca31e58186b438e10754c19349) |
| loan | 대차 문서 만들기 (차입·대여) | POST | `/api/v1/loan` | 입력 |  |  | INV-39 | [열기](https://app.notion.com/p/421b82ca31e581b6b316feca2f7d6de9) |
| loan | 대차 문서 하나 (정산·변경 이력 포함) | GET | `/api/v1/loan/{id}` | 모두 | ✓ |  |  | [열기](https://app.notion.com/p/421b82ca31e5810f92dff346ed5689b9) |
| loan | 대차 문서 수정 | PATCH | `/api/v1/loan/{id}` | 입력 |  |  |  | [열기](https://app.notion.com/p/421b82ca31e5818fab32c5963ecec1df) |
| loan | 대차 문서 삭제 | DELETE | `/api/v1/loan/{id}` | 입력 |  |  |  | [열기](https://app.notion.com/p/421b82ca31e581e39133d539c6182c21) |
| loan | 대차 기한 바꾸기 | POST | `/api/v1/loan/{id}/due-date` | 입력 |  |  |  | [열기](https://app.notion.com/p/421b82ca31e58158b3e5c5a4c6b12ecc) |
| loan | 대여 출고 | POST | `/api/v1/loan/{id}/issue` | 입력 |  | ✓ | INV-35 | [열기](https://app.notion.com/p/421b82ca31e58171ac2cf8bb3c17789f) |
| loan | 차입 받기 (차입 입고·직접 임시 설치) | POST | `/api/v1/loan/{id}/receive` | 입력 |  | ✓ | INV-40 | [열기](https://app.notion.com/p/421b82ca31e581438e74ea880414b3c8) |
| loan | 대차 정산 (차입·대여 3가지 방식) | POST | `/api/v1/loan/{id}/settle` | 입력 |  | ✓ | INV-39, INV-77 | [열기](https://app.notion.com/p/421b82ca31e5812f8d55d53734b8ffe9) |
| loan | 정산 방식 바꾸기 | POST | `/api/v1/loan/{id}/settlement-method` | 관리자 |  | ✓ |  | [열기](https://app.notion.com/p/421b82ca31e581d68df7cc02d06ecd61) |
| loan | 빌려 온 장비 임시 설치 | POST | `/api/v1/loan/{id}/temp-install` | 입력 |  | ✓ | INV-40 | [열기](https://app.notion.com/p/421b82ca31e58143bd10c511521b34c2) |
| product | 구성 묶음 목록 | GET | `/api/v1/product/bundle` | 모두 |  |  |  | [열기](https://app.notion.com/p/421b82ca31e581be97a4c5748ef5c78e) |
| product | 구성 묶음 만들기 | POST | `/api/v1/product/bundle` | 관리자 |  |  |  | [열기](https://app.notion.com/p/421b82ca31e581c388d7d72dddc01e19) |
| product | 구성 묶음 하나 | GET | `/api/v1/product/bundle/{id}` | 모두 |  |  |  | [열기](https://app.notion.com/p/421b82ca31e581b2a5b1df475f37c51c) |
| product | 구성 묶음 수정 | PATCH | `/api/v1/product/bundle/{id}` | 관리자 |  |  |  | [열기](https://app.notion.com/p/421b82ca31e5819a8bdae1e5d6d34ad1) |
| product | 구성 묶음 삭제 | DELETE | `/api/v1/product/bundle/{id}` | 관리자 |  |  |  | [열기](https://app.notion.com/p/421b82ca31e58140ab5bf6e4fed084bf) |
| project | 거래 문서 취소 | POST | `/api/v1/project/trade-document/{id}/cancel` | 입력 |  | ✓ |  | [열기](https://app.notion.com/p/421b82ca31e5816280d9de0921c99c78) |
| project | 매입을 매출로 복사 | POST | `/api/v1/project/trade-document/{id}/copy-to-sales` | 입력 |  |  |  | [열기](https://app.notion.com/p/421b82ca31e58140834fd1f683204e54) |
| project | 거래 품목 잔량 마감 | POST | `/api/v1/project/trade-document/{id}/line/{lineId}/close` | 관리자 |  | ✓ | INV-28 | [열기](https://app.notion.com/p/421b82ca31e581d3bb1bc8540a02a6f5) |
| project | 매입·매출 비교 | GET | `/api/v1/project/{id}/purchase-sales-comparison` | 모두 |  |  |  | [열기](https://app.notion.com/p/421b82ca31e58167a077ff0107ad77ab) |
| project | 한쪽에만 있는 품목 반대쪽으로 복사 | POST | `/api/v1/project/{id}/purchase-sales-comparison/copy-line` | 입력 |  |  |  | [열기](https://app.notion.com/p/421b82ca31e581619cebdb97dc41a997) |
| trash | 삭제 목록 | GET | `/api/v1/trash` | 입력 |  |  |  | [열기](https://app.notion.com/p/421b82ca31e581f89f95e9a802cbf770) |
| trash | 삭제한 것 복구 | POST | `/api/v1/trash/{entityType}/{id}/restore` | 입력 |  |  | INV-31 | [열기](https://app.notion.com/p/421b82ca31e5814fadabcce614fe47a0) |

## 4단계 (15개)

| 모듈 | API | 메서드 | 경로 | 권한 | 금액 | 키 | 관련 INV | 노션 |
|---|---|---|---|---|---|---|---|---|
| cost | 금액 변경 이력 | GET | `/api/v1/cost/change` | 금액보기 | ✓ |  | INV-83 | [열기](https://app.notion.com/p/421b82ca31e5815b90d9e1b65e6043f4) |
| cost | 부대비용 목록 | GET | `/api/v1/cost/extra-cost` | 금액보기 | ✓ |  |  | [열기](https://app.notion.com/p/421b82ca31e5811d9e7fcded6a9792ac) |
| cost | 부대비용 넣기 | POST | `/api/v1/cost/extra-cost` | 금액수정 (입력 그리고 금액수정) | ✓ |  | INV-68, INV-82, INV-83 | [열기](https://app.notion.com/p/421b82ca31e5819c8450d814110bf9b8) |
| cost | 부대비용 하나 | GET | `/api/v1/cost/extra-cost/{id}` | 금액보기 | ✓ |  |  | [열기](https://app.notion.com/p/421b82ca31e581768495f6a1e9c02867) |
| cost | 부대비용 고치기 | PATCH | `/api/v1/cost/extra-cost/{id}` | 금액수정 (입력 그리고 금액수정) | ✓ |  | INV-82, INV-83 | [열기](https://app.notion.com/p/421b82ca31e5812e8e3fe940a5e99a22) |
| cost | 부대비용 삭제 | DELETE | `/api/v1/cost/extra-cost/{id}` | 금액수정 (입력 그리고 금액수정) |  |  |  | [열기](https://app.notion.com/p/421b82ca31e581fd8f02dd65ea7ca98d) |
| cost | 대여료 넣기·고치기·비우기 (빌려준 경우) | PATCH | `/api/v1/cost/loan-fee/{loanDocumentId}` | 금액수정 (입력 그리고 금액수정) | ✓ |  | INV-68, INV-83 | [열기](https://app.notion.com/p/421b82ca31e58116b02be148a6c1decc) |
| cost | 초기 재고 단가 넣기·고치기·비우기 | PATCH | `/api/v1/cost/opening-cost` | 관리자 그리고 금액수정 | ✓ |  | INV-83 | [열기](https://app.notion.com/p/421b82ca31e581dab6fdc95927b5a3f7) |
| cost | 프로젝트 금액·마진 (예정·실제, 품목별) | GET | `/api/v1/cost/project/{projectId}/margin` | 금액보기 | ✓ |  |  | [열기](https://app.notion.com/p/421b82ca31e581e08629cb392c145835) |
| cost | 창고 재고 평가액 | GET | `/api/v1/cost/stock-valuation` | 금액보기 | ✓ |  |  | [열기](https://app.notion.com/p/421b82ca31e5817eae09ffe8cafebdc3) |
| cost | 거래 문서 품목 단가 넣기·고치기·비우기 | PATCH | `/api/v1/cost/trade-document/{id}/line-price` | 금액수정 (입력 그리고 금액수정) | ✓ |  | INV-83 | [열기](https://app.notion.com/p/421b82ca31e581dda05ecfa0716d31c3) |
| dashboard | 홈 화면 집계 | GET | `/api/v1/dashboard/home` | 모두 |  |  |  | [열기](https://app.notion.com/p/421b82ca31e58126a37ac501216a1268) |
| equipment | 보증 목록 (만료일·미확인 찾기) | GET | `/api/v1/equipment/warranty` | 모두 |  |  |  | [열기](https://app.notion.com/p/421b82ca31e58133b239d331d63cdaa1) |
| equipment | 장비 보증 하나 (변경 이력 포함) | GET | `/api/v1/equipment/{id}/warranty` | 모두 |  |  |  | [열기](https://app.notion.com/p/421b82ca31e581dcaf4ec9ce62ec8ce4) |
| equipment | 장비 보증 넣기·고치기 | PATCH | `/api/v1/equipment/{id}/warranty` | 입력 |  |  |  | [열기](https://app.notion.com/p/421b82ca31e5813cb73fea9600446859) |

## 5단계 (4개)

| 모듈 | API | 메서드 | 경로 | 권한 | 금액 | 키 | 관련 INV | 노션 |
|---|---|---|---|---|---|---|---|---|
| importing | 첨부 파일 목록 | GET | `/api/v1/importing/attachment` | 모두 |  |  | INV-86 | [열기](https://app.notion.com/p/422b82ca31e58153bff9e05a4496cfd7) |
| importing | 첨부 파일 올리기 | POST | `/api/v1/importing/attachment` | 입력 |  | ✓ | INV-86 | [열기](https://app.notion.com/p/422b82ca31e58105a93af81e2e4f1540) |
| importing | 첨부 파일 떼기 | DELETE | `/api/v1/importing/attachment/{id}` | 입력 |  |  | INV-86 | [열기](https://app.notion.com/p/422b82ca31e581fca0a3d2cab3eb3e0f) |
| importing | 첨부 파일 열기·내려받기 | GET | `/api/v1/importing/attachment/{id}/content` | 관리자 또는 금액보기 |  |  | INV-86 | [열기](https://app.notion.com/p/422b82ca31e581ddbb51df921c427a14) |
