-- ============================================================
-- 자산관리 시스템 PostgreSQL DDL — ② 추후 수정용 (v2, 제약 추가)
-- 생성: 2026-11-24 / 기준: 노션 '테이블 정의서', '불변 조건 목록'
-- 대상: PostgreSQL 18 이상 (uuidv7(), UNIQUE NULLS NOT DISTINCT 사용)
-- 전제: asset_v1_create.sql이 적용된 DB
-- 내용: v1에서 뺀 CHECK·UNIQUE·부분 유니크 + 보강 제안 P1~P5
-- 주의: ADD CONSTRAINT는 기존 데이터를 검사한다. 위반 데이터가 있으면 실패하고
--       전체가 롤백되므로, 실패 메시지의 제약 이름으로 데이터를 정리한 뒤 다시 실행한다.
--       협의 결과로 코드 목록이 바뀌었으면 gen.py를 고쳐 다시 생성한 뒤 적용한다.
-- 수정: 2026-11-26 auth 제약 2개를 손으로 뺐다(V5 역할·권한 체계). Flyway V1–V5를 적용한 DB에서
--       이 파일 전체가 오류 없이 적용되는 것을 확인했다. 이제 gen3.py 생성 결과와 같지 않다(tools/ddl/README.md).
-- ============================================================

BEGIN;

-- ---------------------------------------------------------------- v1에서 미룬 제약
-- auth.roles — 역할: uq_roles_code는 2026-11-26 뺐다. V5 마이그레이션이 삭제된 역할을 뺀 부분 유니크
--   ux_roles_code(와 ux_roles_name)를 이미 건다. 같은 코드의 삭제된 역할이 있으면 이 제약은 오히려 실패한다.
-- auth.user_permissions — ck_user_permissions_1은 2026-11-26 뺐다. V5가 이 테이블을 지웠다(권한은 role_permissions,
--   권한 코드는 auth.permissions FK로 막는다). 확정 사항 #106.

-- product.product_categories — 품목군
CREATE UNIQUE INDEX ux_product_categories_code ON product.product_categories (code) WHERE deleted_at IS NULL;

-- product.products — 제품
CREATE UNIQUE INDEX ux_products_item_code ON product.products (item_code) WHERE deleted_at IS NULL;

-- product.bundles — 구성 묶음
CREATE UNIQUE INDEX ux_bundles_bundle_code ON product.bundles (bundle_code) WHERE deleted_at IS NULL;

-- product.bundle_components — 구성 묶음 구성품
ALTER TABLE product.bundle_components ADD CONSTRAINT uq_bundle_components_bundle_id_product_id UNIQUE (bundle_id, product_id);

-- warehouse.warehouses — 창고
CREATE UNIQUE INDEX ux_warehouses_warehouse_code ON warehouse.warehouses (warehouse_code) WHERE deleted_at IS NULL;

-- warehouse.locations — 위치(자사 창고 내 위치 + 외부 위치)
ALTER TABLE warehouse.locations ADD CONSTRAINT ck_locations_1 CHECK (location_type IN ('INTERNAL', 'REPAIR', 'LOAN_OUT', 'CUSTOMER_SITE'));
ALTER TABLE warehouse.locations ADD CONSTRAINT ck_locations_2 CHECK ((location_type = 'INTERNAL' AND warehouse_id IS NOT NULL AND partner_id IS NULL) OR (location_type <> 'INTERNAL' AND partner_id IS NOT NULL));
CREATE UNIQUE INDEX ux_locations_location_code ON warehouse.locations (location_code) WHERE deleted_at IS NULL;

-- partner.partners — 거래처
CREATE UNIQUE INDEX ux_partners_business_reg_no ON partner.partners (business_reg_no) WHERE business_reg_no IS NOT NULL AND deleted_at IS NULL;

-- partner.partner_roles — 거래처 역할
ALTER TABLE partner.partner_roles ADD CONSTRAINT ck_partner_roles_1 CHECK (role IN ('CUSTOMER', 'SUPPLIER'));

-- inventory.stock_transactions — 처리 묶음(원장 헤더)
ALTER TABLE inventory.stock_transactions ADD CONSTRAINT uq_stock_transactions_transaction_no UNIQUE (transaction_no);
ALTER TABLE inventory.stock_transactions ADD CONSTRAINT ck_stock_transactions_1 CHECK (transaction_type IN ('OPENING', 'RECEIPT', 'UNPLANNED_RECEIPT', 'ISSUE', 'TRANSFER', 'ADJUSTMENT', 'CUSTOMER_RETURN', 'INSPECTION_RESULT', 'SUPPLIER_RETURN', 'REPAIR_OUT', 'REPAIR_IN', 'EXCHANGE', 'DISPOSAL', 'LOAN_IN_RECEIPT', 'LOAN_IN_REPAY', 'LOAN_IN_RETURN', 'TEMP_INSTALL', 'LOAN_OUT_ISSUE', 'LOAN_OUT_RETURN', 'LOAN_OUT_SETTLE', 'OWNERSHIP_TRANSFER', 'REVERSAL', 'CORRECTION'));
ALTER TABLE inventory.stock_transactions ADD CONSTRAINT ck_stock_transactions_2 CHECK (status IN ('DRAFT', 'POSTED'));

-- inventory.ledger_entries — 재고 원장(INSERT 전용)
ALTER TABLE inventory.ledger_entries ADD CONSTRAINT uq_ledger_entries_transaction_id_line_no UNIQUE (transaction_id, line_no);
ALTER TABLE inventory.ledger_entries ADD CONSTRAINT ck_ledger_entries_1 CHECK (stock_condition IN ('AVAILABLE', 'INSPECTION', 'DEFECTIVE', 'IN_REPAIR'));
ALTER TABLE inventory.ledger_entries ADD CONSTRAINT ck_ledger_entries_2 CHECK (owner_type IN ('OWN', 'THIRD_PARTY'));

-- inventory.stock_balances — 현재 재고(잠금 대상)
ALTER TABLE inventory.stock_balances ADD CONSTRAINT ck_stock_balances_1 CHECK (stock_condition IN ('AVAILABLE', 'INSPECTION', 'DEFECTIVE', 'IN_REPAIR'));
ALTER TABLE inventory.stock_balances ADD CONSTRAINT ck_stock_balances_2 CHECK (owner_type IN ('OWN', 'THIRD_PARTY'));

-- inventory.period_closings — 월 마감
ALTER TABLE inventory.period_closings ADD CONSTRAINT ck_period_closings_1 CHECK (status IN ('OPEN', 'CLOSED'));

-- inventory.period_closing_events — 마감·해제 이력
ALTER TABLE inventory.period_closing_events ADD CONSTRAINT ck_period_closing_events_1 CHECK (action IN ('CLOSE', 'REOPEN'));

-- inventory.stock_counts — 재고 실사
ALTER TABLE inventory.stock_counts ADD CONSTRAINT uq_stock_counts_count_no UNIQUE (count_no);
ALTER TABLE inventory.stock_counts ADD CONSTRAINT ck_stock_counts_1 CHECK (scope_type IN ('LOCATION', 'PRODUCT'));
ALTER TABLE inventory.stock_counts ADD CONSTRAINT ck_stock_counts_2 CHECK (status IN ('PREPARED', 'IN_PROGRESS', 'REVIEW', 'APPROVED', 'CANCELLED'));

-- inventory.stock_count_scopes — 실사 잠금 범위
ALTER TABLE inventory.stock_count_scopes ADD CONSTRAINT ck_stock_count_scopes_1 CHECK (location_id IS NOT NULL OR product_id IS NOT NULL);

-- inventory.stock_count_lines — 실사 품목
ALTER TABLE inventory.stock_count_lines ADD CONSTRAINT ck_stock_count_lines_1 CHECK (stock_condition IN ('AVAILABLE', 'INSPECTION', 'DEFECTIVE', 'IN_REPAIR'));
ALTER TABLE inventory.stock_count_lines ADD CONSTRAINT ck_stock_count_lines_2 CHECK (owner_type IN ('OWN', 'THIRD_PARTY'));
ALTER TABLE inventory.stock_count_lines ADD CONSTRAINT ck_stock_count_lines_3 CHECK ((owner_type = 'OWN' AND owner_partner_id IS NULL) OR (owner_type = 'THIRD_PARTY' AND owner_partner_id IS NOT NULL));

-- inventory.stock_count_serials — 실사 시리얼 대조
ALTER TABLE inventory.stock_count_serials ADD CONSTRAINT ck_stock_count_serials_1 CHECK (result IN ('MATCHED', 'MISSING', 'UNEXPECTED'));

-- equipment.equipment — 개별 장비(시리얼)
ALTER TABLE equipment.equipment ADD CONSTRAINT ck_equipment_1 CHECK (serial_status IN ('CONFIRMED', 'UNKNOWN'));
ALTER TABLE equipment.equipment ADD CONSTRAINT ck_equipment_2 CHECK (status IN ('IN_STOCK', 'INSPECTION', 'DEFECTIVE', 'IN_REPAIR', 'ISSUED', 'DELIVERED', 'TEMP_INSTALLED', 'LOANED_OUT', 'LOST', 'REPLACED', 'DISPOSED', 'RETURNED_TO_SUPPLIER', 'TRANSFERRED_OUT', 'RECEIPT_CANCELLED'));
ALTER TABLE equipment.equipment ADD CONSTRAINT ck_equipment_3 CHECK (owner_type IN ('OWN', 'THIRD_PARTY'));
ALTER TABLE equipment.equipment ADD CONSTRAINT ck_equipment_4 CHECK ((owner_type = 'OWN' AND owner_partner_id IS NULL) OR (owner_type = 'THIRD_PARTY' AND owner_partner_id IS NOT NULL));
ALTER TABLE equipment.equipment ADD CONSTRAINT ck_equipment_5 CHECK (serial_status = 'UNKNOWN' OR serial_no IS NOT NULL);
ALTER TABLE equipment.equipment ADD CONSTRAINT ck_equipment_6 CHECK (origin_type IN ('LEDGER', 'PRE_CUTOVER_DELIVERY'));
CREATE UNIQUE INDEX ux_equipment_product_serial ON equipment.equipment (product_id, serial_no) WHERE serial_no IS NOT NULL;

-- equipment.warranties — 보증
ALTER TABLE equipment.warranties ADD CONSTRAINT uq_warranties_equipment_id UNIQUE (equipment_id);
ALTER TABLE equipment.warranties ADD CONSTRAINT ck_warranties_1 CHECK (status IN ('CONFIRMED', 'UNKNOWN'));
ALTER TABLE equipment.warranties ADD CONSTRAINT ck_warranties_2 CHECK (end_date IS NULL OR start_date IS NULL OR end_date >= start_date);
ALTER TABLE equipment.warranties ADD CONSTRAINT ck_warranties_3 CHECK (basis IS NULL OR basis IN ('DELIVERY', 'MANUFACTURER', 'PURCHASE', 'MANUAL'));

-- project.projects — 프로젝트
ALTER TABLE project.projects ADD CONSTRAINT uq_projects_project_code UNIQUE (project_code);
ALTER TABLE project.projects ADD CONSTRAINT ck_projects_1 CHECK (status IN ('ACTIVE', 'COMPLETED', 'CANCELLED'));

-- project.trade_documents — 거래 문서(발주서·매출·선발주)
ALTER TABLE project.trade_documents ADD CONSTRAINT ck_trade_documents_1 CHECK (trade_type IN ('PURCHASE', 'SALES', 'PRE_ORDER'));
ALTER TABLE project.trade_documents ADD CONSTRAINT ck_trade_documents_2 CHECK (status IN ('DRAFT', 'CONFIRMED', 'COMPLETED', 'CANCELLED'));
CREATE UNIQUE INDEX ux_trade_documents_partner_docno ON project.trade_documents (partner_id, document_no) WHERE deleted_at IS NULL AND document_no IS NOT NULL;

-- project.trade_lines — 거래 품목
ALTER TABLE project.trade_lines ADD CONSTRAINT uq_trade_lines_document_id_line_no UNIQUE (document_id, line_no);
ALTER TABLE project.trade_lines ADD CONSTRAINT ck_trade_lines_5 CHECK (route IN ('WAREHOUSE', 'DIRECT'));

-- allocation.allocations — 배정
ALTER TABLE allocation.allocations ADD CONSTRAINT ck_allocations_3 CHECK (target_type IN ('PROJECT', 'LOAN_REPAY'));
ALTER TABLE allocation.allocations ADD CONSTRAINT ck_allocations_4 CHECK ((target_type = 'PROJECT' AND project_id IS NOT NULL) OR (target_type = 'LOAN_REPAY' AND loan_document_id IS NOT NULL));
ALTER TABLE allocation.allocations ADD CONSTRAINT ck_allocations_5 CHECK (source_type IN ('STOCK', 'RECEIVED', 'PLANNED'));
ALTER TABLE allocation.allocations ADD CONSTRAINT ck_allocations_6 CHECK (source_type = 'STOCK' OR source_trade_line_id IS NOT NULL);
ALTER TABLE allocation.allocations ADD CONSTRAINT ck_allocations_7 CHECK (owner_type IS NULL OR owner_type IN ('OWN', 'THIRD_PARTY'));
ALTER TABLE allocation.allocations ADD CONSTRAINT ck_allocations_8 CHECK (status IN ('ACTIVE', 'RELEASED', 'CONSUMED'));

-- allocation.allocation_events — 배정 이력
ALTER TABLE allocation.allocation_events ADD CONSTRAINT ck_allocation_events_1 CHECK (action IN ('ALLOCATE', 'CHANGE', 'RELEASE', 'CONSUME', 'CONVERT'));

-- delivery.deliveries — 납품 회차
ALTER TABLE delivery.deliveries ADD CONSTRAINT uq_deliveries_delivery_no UNIQUE (delivery_no);
ALTER TABLE delivery.deliveries ADD CONSTRAINT ck_deliveries_1 CHECK (route IN ('WAREHOUSE', 'DIRECT'));
ALTER TABLE delivery.deliveries ADD CONSTRAINT ck_deliveries_2 CHECK (status IN ('DRAFT', 'POSTED', 'CANCELLED'));
ALTER TABLE delivery.deliveries ADD CONSTRAINT ck_deliveries_3 CHECK ((bundle_id IS NULL AND bundle_set_quantity IS NULL) OR (bundle_id IS NOT NULL AND bundle_set_quantity > 0));

-- delivery.delivery_lines — 납품 품목
ALTER TABLE delivery.delivery_lines ADD CONSTRAINT uq_delivery_lines_delivery_id_line_no UNIQUE (delivery_id, line_no);

-- delivery.delivery_returns — 고객 반품
ALTER TABLE delivery.delivery_returns ADD CONSTRAINT ck_delivery_returns_2 CHECK (delivery_line_id IS NOT NULL OR (equipment_id IS NOT NULL AND quantity = 1));

-- loan.loan_documents — 대차 문서(차입·대여)
ALTER TABLE loan.loan_documents ADD CONSTRAINT uq_loan_documents_loan_no UNIQUE (loan_no);
ALTER TABLE loan.loan_documents ADD CONSTRAINT ck_loan_documents_1 CHECK (direction IN ('IN', 'OUT'));
ALTER TABLE loan.loan_documents ADD CONSTRAINT ck_loan_documents_2 CHECK (settlement_method IN ('IN_KIND', 'CONVERT', 'RETURN_ORIGINAL'));
ALTER TABLE loan.loan_documents ADD CONSTRAINT ck_loan_documents_3 CHECK (status IN ('OPEN', 'SETTLED', 'CANCELLED'));

-- loan.loan_lines — 대차 품목
ALTER TABLE loan.loan_lines ADD CONSTRAINT uq_loan_lines_loan_id_line_no UNIQUE (loan_id, line_no);
ALTER TABLE loan.loan_lines ADD CONSTRAINT ck_loan_lines_3 CHECK (moved_quantity >= 0 AND moved_quantity <= quantity);

-- loan.loan_settlements — 대차 정산 기록
ALTER TABLE loan.loan_settlements ADD CONSTRAINT ck_loan_settlements_2 CHECK (method IN ('IN_KIND', 'CONVERT', 'RETURN_ORIGINAL'));
ALTER TABLE loan.loan_settlements ADD CONSTRAINT ck_loan_settlements_3 CHECK (status IN ('PENDING_APPROVAL', 'POSTED', 'REJECTED', 'CANCELLED'));
ALTER TABLE loan.loan_settlements ADD CONSTRAINT ck_loan_settlements_4 CHECK (method <> 'CONVERT' OR trade_document_id IS NOT NULL);
ALTER TABLE loan.loan_settlements ADD CONSTRAINT ck_loan_settlements_5 CHECK (equipment_id IS NULL OR quantity = 1);

-- trash.trash_events — 삭제·복구 이력
ALTER TABLE trash.trash_events ADD CONSTRAINT ck_trash_events_1 CHECK (action IN ('DELETE', 'RESTORE'));

-- cost.currencies — 통화
ALTER TABLE cost.currencies ADD CONSTRAINT ck_currencies_1 CHECK (minor_unit BETWEEN 0 AND 4);

-- cost.line_prices — 거래 품목 단가
ALTER TABLE cost.line_prices ADD CONSTRAINT ck_line_prices_1 CHECK (exchange_rate > 0);
ALTER TABLE cost.line_prices ADD CONSTRAINT ck_line_prices_2 CHECK (currency = 'KRW' OR exchange_rate_date IS NOT NULL);
ALTER TABLE cost.line_prices ADD CONSTRAINT ck_line_prices_3 CHECK (attribution_basis IN ('DOCUMENT_DATE', 'FULFILLED_DATE', 'MANUAL'));
ALTER TABLE cost.line_prices ADD CONSTRAINT ck_line_prices_4 CHECK ((attribution_basis = 'MANUAL') = (attribution_date IS NOT NULL));

-- cost.extra_costs — 부대비용
ALTER TABLE cost.extra_costs ADD CONSTRAINT ck_extra_costs_1 CHECK (cost_type IN ('SHIPPING', 'INSTALL', 'RENTAL', 'OTHER'));
ALTER TABLE cost.extra_costs ADD CONSTRAINT ck_extra_costs_2 CHECK (exchange_rate > 0);
ALTER TABLE cost.extra_costs ADD CONSTRAINT ck_extra_costs_3 CHECK (cost_type <> 'RENTAL' OR loan_document_id IS NOT NULL);
ALTER TABLE cost.extra_costs ADD CONSTRAINT ck_extra_costs_4 CHECK (currency = 'KRW' OR exchange_rate_date IS NOT NULL);
ALTER TABLE cost.extra_costs ADD CONSTRAINT ck_extra_costs_5 CHECK (attribution_basis IN ('COST_DATE', 'MANUAL'));
ALTER TABLE cost.extra_costs ADD CONSTRAINT ck_extra_costs_6 CHECK ((attribution_basis = 'MANUAL') = (attribution_date IS NOT NULL));

-- cost.loan_fees — 대여료
ALTER TABLE cost.loan_fees ADD CONSTRAINT ck_loan_fees_1 CHECK (exchange_rate > 0);
ALTER TABLE cost.loan_fees ADD CONSTRAINT ck_loan_fees_2 CHECK (currency = 'KRW' OR exchange_rate_date IS NOT NULL);
ALTER TABLE cost.loan_fees ADD CONSTRAINT ck_loan_fees_3 CHECK (attribution_basis IN ('SETTLED_DATE', 'DUE_DATE', 'MANUAL'));
ALTER TABLE cost.loan_fees ADD CONSTRAINT ck_loan_fees_4 CHECK ((attribution_basis = 'MANUAL') = (attribution_date IS NOT NULL));

-- cost.opening_costs — 초기 재고 단가
ALTER TABLE cost.opening_costs ADD CONSTRAINT ck_opening_costs_1 CHECK (unit_cost >= 0);
ALTER TABLE cost.opening_costs ADD CONSTRAINT ck_opening_costs_2 CHECK (exchange_rate > 0);
ALTER TABLE cost.opening_costs ADD CONSTRAINT ck_opening_costs_3 CHECK (currency = 'KRW' OR exchange_rate_date IS NOT NULL);
ALTER TABLE cost.opening_costs ADD CONSTRAINT ck_opening_costs_4 CHECK (attribution_basis IN ('CUTOVER_DATE', 'MANUAL'));
ALTER TABLE cost.opening_costs ADD CONSTRAINT ck_opening_costs_5 CHECK ((attribution_basis = 'MANUAL') = (attribution_date IS NOT NULL));

-- cost.cost_changes — 금액 변경 이력
ALTER TABLE cost.cost_changes ADD CONSTRAINT ck_cost_changes_1 CHECK (target_type IN ('LINE_PRICE', 'EXTRA_COST', 'LOAN_FEE', 'OPENING_COST'));

-- importing.files — 첨부 파일(증빙)
ALTER TABLE importing.files ADD CONSTRAINT uq_files_storage_key UNIQUE (storage_key);
ALTER TABLE importing.files ADD CONSTRAINT ck_files_1 CHECK (target_type IN ('TRADE_DOCUMENT'));
ALTER TABLE importing.files ADD CONSTRAINT ck_files_2 CHECK (content_type IN ('application/pdf', 'image/jpeg', 'image/png'));
ALTER TABLE importing.files ADD CONSTRAINT ck_files_3 CHECK (size_bytes > 0 AND size_bytes <= 20971520);

-- common.idempotency_keys — 중복 요청 키
ALTER TABLE common.idempotency_keys ADD CONSTRAINT ck_idempotency_keys_1 CHECK (status IN ('IN_PROGRESS', 'DONE'));
ALTER TABLE common.idempotency_keys ADD CONSTRAINT ck_idempotency_keys_2 CHECK (status = 'IN_PROGRESS' OR (response_status IS NOT NULL AND completed_at IS NOT NULL));

-- admin.review_requests — 승인·확인 요청
ALTER TABLE admin.review_requests ADD CONSTRAINT ck_review_requests_1 CHECK (request_type IN ('DISPOSAL', 'LOAN_OUT', 'EQUIVALENT_SETTLEMENT', 'COUNT_DIFFERENCE', 'UNPLANNED_RECEIPT', 'SERIAL_CHANGE', 'LOAN_DUE_CHANGE'));
ALTER TABLE admin.review_requests ADD CONSTRAINT ck_review_requests_2 CHECK (status IN ('PENDING', 'APPROVED', 'REJECTED', 'CONFIRMED'));
ALTER TABLE admin.review_requests ADD CONSTRAINT ck_review_requests_3 CHECK (status NOT IN ('APPROVED', 'REJECTED') OR request_type IN ('DISPOSAL', 'LOAN_OUT', 'EQUIVALENT_SETTLEMENT', 'COUNT_DIFFERENCE'));
ALTER TABLE admin.review_requests ADD CONSTRAINT ck_review_requests_4 CHECK (status <> 'CONFIRMED' OR request_type IN ('UNPLANNED_RECEIPT', 'SERIAL_CHANGE', 'LOAN_DUE_CHANGE'));
ALTER TABLE admin.review_requests ADD CONSTRAINT ck_review_requests_5 CHECK (status = 'PENDING' OR (decided_by IS NOT NULL AND decided_at IS NOT NULL));
ALTER TABLE admin.review_requests ADD CONSTRAINT ck_review_requests_6 CHECK (status <> 'REJECTED' OR decision_reason IS NOT NULL);
CREATE UNIQUE INDEX ux_review_requests_pending ON admin.review_requests (request_type, target_type, target_id) WHERE status = 'PENDING';

-- admin.notifications — 알림
ALTER TABLE admin.notifications ADD CONSTRAINT ck_notifications_1 CHECK (notification_type IN ('REVIEW_REJECTED', 'INTEGRITY_ALERT', 'ALLOCATION_RELEASED', 'WARRANTY_EXPIRING'));

-- admin.integrity_check_results — 정합성 점검 결과
ALTER TABLE admin.integrity_check_results ADD CONSTRAINT ck_integrity_check_results_1 CHECK (resolved_at IS NULL OR resolved_at >= first_found_at);
CREATE UNIQUE INDEX ux_integrity_check_results_open ON admin.integrity_check_results (check_code, target_type, target_key) WHERE resolved_at IS NULL;

-- ---------------------------------------------------------------- 보강 제안 P1~P5 (불변 조건 목록 9절)
-- P1 장비 1대에 활성 배정 1건(INV-24)
CREATE UNIQUE INDEX ux_allocations_active_equipment
    ON allocation.allocations (equipment_id)
    WHERE status = 'ACTIVE' AND equipment_id IS NOT NULL;
-- P2 시리얼 장비 원장 줄은 수량 ±1(INV-19)
ALTER TABLE inventory.ledger_entries ADD CONSTRAINT ck_ledger_entries_equipment_unit CHECK (equipment_id IS NULL OR quantity_delta IN (1, -1));
-- P2 시리얼 장비 납품 줄은 수량 1(INV-19)
ALTER TABLE delivery.delivery_lines ADD CONSTRAINT ck_delivery_lines_equipment_unit CHECK (equipment_id IS NULL OR quantity = 1);
-- P2 시리얼 장비 배정은 수량 1(INV-19)
ALTER TABLE allocation.allocations ADD CONSTRAINT ck_allocations_equipment_unit CHECK (equipment_id IS NULL OR quantity = 1);
-- P3 원화 단가는 환율 1(INV-52)
ALTER TABLE cost.line_prices ADD CONSTRAINT ck_line_prices_krw_rate CHECK (currency <> 'KRW' OR exchange_rate = 1);
-- P3 원화 부대비용은 환율 1(INV-52)
ALTER TABLE cost.extra_costs ADD CONSTRAINT ck_extra_costs_krw_rate CHECK (currency <> 'KRW' OR exchange_rate = 1);
-- P3 원화 대여료는 환율 1(INV-52)
ALTER TABLE cost.loan_fees ADD CONSTRAINT ck_loan_fees_krw_rate CHECK (currency <> 'KRW' OR exchange_rate = 1);
-- P3 원화 초기 재고 단가는 환율 1(INV-52)
ALTER TABLE cost.opening_costs ADD CONSTRAINT ck_opening_costs_krw_rate CHECK (currency <> 'KRW' OR exchange_rate = 1);
-- P4 마감된 달 원장 추가 차단 함수(INV-15, INV-46)
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
-- P4 마감된 달 원장 추가 차단 트리거(INV-15, INV-46)
CREATE TRIGGER trg_ledger_entries_closed_period
    BEFORE INSERT ON inventory.ledger_entries
    FOR EACH ROW EXECUTE FUNCTION inventory.fn_ledger_entries_closed_period();
-- P5 자기 자신 취소 금지(INV-11)
ALTER TABLE inventory.ledger_entries ADD CONSTRAINT ck_ledger_entries_reversal_self CHECK (reversal_of_entry_id IS NULL OR reversal_of_entry_id <> id);

-- P4 주의: 마감 작업은 해당 월 period_closings 행을 FOR UPDATE로 잠그고,
--          원장 입력 트랜잭션은 같은 행을 FOR SHARE로 읽어 순서를 보장한다.

COMMIT;
