# -*- coding: utf-8 -*-
"""자산관리 시스템 DDL 생성기 (테이블 정의서 기준).
PostgreSQL 운영용 DDL과 ERDCloud 가져오기용 MySQL DDL을 같은 정의에서 생성한다."""

# ---------------------------------------------------------------- 공통 상수
TX_TYPES = ["OPENING", "RECEIPT", "UNPLANNED_RECEIPT", "ISSUE", "TRANSFER", "ADJUSTMENT",
            "CUSTOMER_RETURN", "INSPECTION_RESULT", "SUPPLIER_RETURN", "REPAIR_OUT", "REPAIR_IN",
            "EXCHANGE", "DISPOSAL",
            "LOAN_IN_RECEIPT", "LOAN_IN_REPAY", "LOAN_IN_RETURN", "TEMP_INSTALL",
            "LOAN_OUT_ISSUE", "LOAN_OUT_RETURN", "LOAN_OUT_SETTLE", "OWNERSHIP_TRANSFER",
            "REVERSAL", "CORRECTION"]
CONDITIONS = ["AVAILABLE", "INSPECTION", "DEFECTIVE", "IN_REPAIR"]
OWNER_TYPES = ["OWN", "THIRD_PARTY"]
EQUIP_STATUS = ["IN_STOCK", "INSPECTION", "DEFECTIVE", "IN_REPAIR", "ISSUED", "DELIVERED",
                "TEMP_INSTALLED", "LOANED_OUT", "LOST", "REPLACED", "DISPOSED",
                "RETURNED_TO_SUPPLIER", "TRANSFERRED_OUT", "RECEIPT_CANCELLED"]


def inlist(col, values):
    return f"{col} IN (" + ", ".join(f"'{v}'" for v in values) + ")"


def C(name, typ, nn=False, default=None, comment=""):
    return dict(name=name, type=typ, nn=nn, default=default, comment=comment)


def ID():
    return C("id", "uuid", True, "uuidv7()", "ID (UUID v7, 앱에서 생성. DB 기본값도 v7, PostgreSQL 18)")


def AUD():
    return [C("created_at", "timestamptz", True, "now()", "생성 시각"),
            C("created_by", "uuid", True, comment="생성자"),
            C("updated_at", "timestamptz", comment="수정 시각"),
            C("updated_by", "uuid", comment="수정자"),
            C("version", "integer", True, "0", "버전(낙관적 잠금)")]


def DEL():
    return [C("deleted_at", "timestamptz", comment="삭제 시각"),
            C("deleted_by", "uuid", comment="삭제자")]


def OWNER(nn=True):
    return [C("owner_type", "varchar(20)", nn, "'OWN'" if nn else None, "소유 구분(자사/타사)"),
            C("owner_partner_id", "uuid", comment="타사 소유 업체")]


OWNER_CHECK = ("(owner_type = 'OWN' AND owner_partner_id IS NULL) OR "
               "(owner_type = 'THIRD_PARTY' AND owner_partner_id IS NOT NULL)")

TABLES = []


def T(schema, name, comment, cols, pk=("id",), uniques=(), checks=(), fks=(),
      indexes=(), pg_extra=()):
    TABLES.append(dict(schema=schema, name=name, comment=comment, cols=cols, pk=list(pk),
                       uniques=list(uniques), checks=list(checks), fks=list(fks),
                       indexes=list(indexes), pg_extra=list(pg_extra)))


# ================================================================ auth
T("auth", "users", "사용자", [
    ID(),
    C("login_id", "varchar(50)", True, comment="로그인 ID"),
    C("name", "varchar(100)", True, comment="이름"),
    C("email", "varchar(200)", comment="이메일"),
    C("password_hash", "varchar(200)", True, comment="비밀번호 해시"),
    C("is_active", "boolean", True, "true", "사용 여부"),
    C("last_login_at", "timestamptz", comment="마지막 로그인"),
    C("tokens_valid_after", "timestamptz", comment="토큰 무효 기준 시각"),
    C("must_change_password", "boolean", True, "false", "다음 로그인 때 비밀번호 변경 필요"),
    *AUD(), *DEL()],
  pg_extra=["CREATE UNIQUE INDEX ux_users_login_id ON auth.users (login_id) WHERE deleted_at IS NULL;"])

T("auth", "roles", "역할", [
    ID(),
    C("code", "varchar(30)", True, comment="역할 코드"),
    C("name", "varchar(100)", True, comment="역할명")], uniques=[["code"]])

T("auth", "user_roles", "사용자 역할", [
    C("user_id", "uuid", True, comment="사용자"),
    C("role_id", "uuid", True, comment="역할")],
  pk=("user_id", "role_id"),
  fks=[("user_id", "users"), ("role_id", "roles")])

T("auth", "user_permissions", "사용자 추가 권한", [
    C("user_id", "uuid", True, comment="사용자"),
    C("permission", "varchar(30)", True, comment="권한(COST_VIEW/COST_EDIT)")],
  pk=("user_id", "permission"),
  checks=[inlist("permission", ["COST_VIEW", "COST_EDIT"])],
  fks=[("user_id", "users")])

T("auth", "oauth2_authorization", "로그인 토큰(Spring Authorization Server)", [
    C("id", "varchar(100)", True, comment="인가 ID"),
    C("registered_client_id", "varchar(100)", True, comment="클라이언트 ID"),
    C("principal_name", "varchar(200)", True, comment="사용자(로그인 ID)"),
    C("authorization_grant_type", "varchar(100)", True, comment="인가 방식"),
    C("authorized_scopes", "varchar(1000)", comment="허용 범위"),
    C("attributes", "text", comment="속성"),
    C("state", "varchar(500)", comment="상태 값"),
    C("authorization_code_value", "text", comment="인가 코드"),
    C("authorization_code_issued_at", "timestamp", comment="인가 코드 발급 시각"),
    C("authorization_code_expires_at", "timestamp", comment="인가 코드 만료 시각"),
    C("authorization_code_metadata", "text", comment="인가 코드 메타데이터"),
    C("access_token_value", "text", comment="access token"),
    C("access_token_issued_at", "timestamp", comment="access token 발급 시각"),
    C("access_token_expires_at", "timestamp", comment="access token 만료 시각"),
    C("access_token_metadata", "text", comment="access token 메타데이터"),
    C("access_token_type", "varchar(100)", comment="access token 유형"),
    C("access_token_scopes", "varchar(1000)", comment="access token 범위"),
    C("oidc_id_token_value", "text", comment="ID 토큰"),
    C("oidc_id_token_issued_at", "timestamp", comment="ID 토큰 발급 시각"),
    C("oidc_id_token_expires_at", "timestamp", comment="ID 토큰 만료 시각"),
    C("oidc_id_token_metadata", "text", comment="ID 토큰 메타데이터"),
    C("refresh_token_value", "text", comment="refresh token"),
    C("refresh_token_issued_at", "timestamp", comment="refresh token 발급 시각"),
    C("refresh_token_expires_at", "timestamp", comment="refresh token 만료 시각"),
    C("refresh_token_metadata", "text", comment="refresh token 메타데이터"),
    C("user_code_value", "text", comment="기기 인증 사용자 코드"),
    C("user_code_issued_at", "timestamp", comment="사용자 코드 발급 시각"),
    C("user_code_expires_at", "timestamp", comment="사용자 코드 만료 시각"),
    C("user_code_metadata", "text", comment="사용자 코드 메타데이터"),
    C("device_code_value", "text", comment="기기 코드"),
    C("device_code_issued_at", "timestamp", comment="기기 코드 발급 시각"),
    C("device_code_expires_at", "timestamp", comment="기기 코드 만료 시각"),
    C("device_code_metadata", "text", comment="기기 코드 메타데이터")])

# ================================================================ product
T("product", "product_categories", "품목군", [
    ID(),
    C("code", "varchar(30)", True, comment="품목군 코드"),
    C("name", "varchar(100)", True, comment="품목군명"),
    C("sort_order", "integer", True, "0", "표시 순서"),
    C("is_active", "boolean", True, "true", "사용 여부"),
    *DEL()],
  pg_extra=["CREATE UNIQUE INDEX ux_product_categories_code ON product.product_categories (code) WHERE deleted_at IS NULL;"])

T("product", "products", "제품", [
    ID(),
    C("item_code", "varchar(50)", True, comment="Item Code(앞자리 0 보존)"),
    C("product_name", "varchar(200)", True, comment="제품명"),
    C("model_name", "varchar(100)", comment="모델명"),
    C("category_id", "uuid", True, comment="품목군"),
    C("manufacturer", "varchar(100)", comment="제조사"),
    C("component_role", "varchar(100)", comment="구성품 역할"),
    C("specification", "text", comment="규격/설명"),
    C("unit", "varchar(20)", True, "'EA'", "단위"),
    C("serial_managed", "boolean", True, "false", "시리얼 관리 여부"),
    C("is_active", "boolean", True, "true", "사용 여부"),
    C("note", "text", comment="비고"),
    *AUD(), *DEL()],
  fks=[("category_id", "product_categories")],
  pg_extra=["CREATE UNIQUE INDEX ux_products_item_code ON product.products (item_code) WHERE deleted_at IS NULL;"])

T("product", "product_changes", "제품 변경 이력", [
    ID(),
    C("product_id", "uuid", True, comment="제품"),
    C("field_name", "varchar(50)", True, comment="변경 항목"),
    C("old_value", "text", comment="이전 값"),
    C("new_value", "text", comment="새 값"),
    C("reason", "text", comment="사유"),
    C("changed_by", "uuid", True, comment="변경자"),
    C("changed_at", "timestamptz", True, "now()", "변경 시각")],
  fks=[("product_id", "products")])

T("product", "bundles", "구성 묶음", [
    ID(),
    C("bundle_code", "varchar(30)", True, comment="묶음 코드"),
    C("bundle_name", "varchar(200)", True, comment="묶음명"),
    C("is_active", "boolean", True, "true", "사용 여부"),
    C("note", "text", comment="비고"),
    *AUD(), *DEL()],
  pg_extra=["CREATE UNIQUE INDEX ux_bundles_bundle_code ON product.bundles (bundle_code) WHERE deleted_at IS NULL;"])

T("product", "bundle_components", "구성 묶음 구성품", [
    ID(),
    C("bundle_id", "uuid", True, comment="묶음"),
    C("product_id", "uuid", True, comment="구성품"),
    C("quantity_per_set", "integer", True, comment="세트당 수량")],
  uniques=[["bundle_id", "product_id"]], checks=["quantity_per_set > 0"],
  fks=[("bundle_id", "bundles"), ("product_id", "products")])

# ================================================================ warehouse
T("warehouse", "warehouses", "창고", [
    ID(),
    C("warehouse_code", "varchar(30)", True, comment="창고 코드"),
    C("warehouse_name", "varchar(100)", True, comment="창고명"),
    C("address", "varchar(300)", comment="주소"),
    C("is_active", "boolean", True, "true", "사용 여부"),
    C("note", "text", comment="비고"),
    *AUD(), *DEL()],
  pg_extra=["CREATE UNIQUE INDEX ux_warehouses_warehouse_code ON warehouse.warehouses (warehouse_code) WHERE deleted_at IS NULL;"])

T("warehouse", "locations", "위치(자사 창고 내 위치 + 외부 위치)", [
    ID(),
    C("location_code", "varchar(30)", True, comment="위치 코드"),
    C("location_name", "varchar(100)", True, comment="위치명"),
    C("location_type", "varchar(20)", True, "'INTERNAL'", "위치 유형"),
    C("warehouse_id", "uuid", comment="창고(자사 위치)"),
    C("partner_id", "uuid", comment="상대 업체(외부 위치)"),
    C("zone", "varchar(30)", comment="구역"),
    C("rack", "varchar(30)", comment="랙"),
    C("shelf", "varchar(30)", comment="선반"),
    C("is_active", "boolean", True, "true", "사용 여부"),
    C("note", "text", comment="비고"),
    *AUD(), *DEL()],
  pg_extra=["CREATE UNIQUE INDEX ux_locations_location_code ON warehouse.locations (location_code) WHERE deleted_at IS NULL;"],
  checks=[inlist("location_type", ["INTERNAL", "REPAIR", "LOAN_OUT", "CUSTOMER_SITE"]),
          "(location_type = 'INTERNAL' AND warehouse_id IS NOT NULL AND partner_id IS NULL) OR "
          "(location_type <> 'INTERNAL' AND partner_id IS NOT NULL)"],
  fks=[("warehouse_id", "warehouses"), ("partner_id", "partners")])

# ================================================================ partner
T("partner", "partners", "거래처", [
    ID(),
    C("partner_name", "varchar(200)", True, comment="거래처명"),
    C("business_reg_no", "varchar(20)", comment="사업자등록번호"),
    C("address", "varchar(300)", comment="주소"),
    C("phone", "varchar(50)", comment="대표 번호"),
    C("is_active", "boolean", True, "true", "사용 여부"),
    C("note", "text", comment="비고"),
    *AUD(), *DEL()],
  pg_extra=["CREATE UNIQUE INDEX ux_partners_business_reg_no ON partner.partners (business_reg_no) "
            "WHERE business_reg_no IS NOT NULL AND deleted_at IS NULL;"])

T("partner", "partner_roles", "거래처 역할", [
    C("partner_id", "uuid", True, comment="거래처"),
    C("role", "varchar(20)", True, comment="역할(고객사/공급사)")],
  pk=("partner_id", "role"), checks=[inlist("role", ["CUSTOMER", "SUPPLIER"])],
  fks=[("partner_id", "partners")])

T("partner", "contacts", "거래처 담당자", [
    ID(),
    C("partner_id", "uuid", True, comment="거래처"),
    C("name", "varchar(100)", True, comment="담당자명"),
    C("department", "varchar(100)", comment="소속"),
    C("position", "varchar(100)", comment="직위"),
    C("phone", "varchar(50)", comment="번호"),
    C("email", "varchar(200)", comment="이메일"),
    C("is_primary", "boolean", True, "false", "주 담당자"),
    *AUD(), *DEL()], fks=[("partner_id", "partners")])

# ================================================================ inventory
T("inventory", "stock_transactions", "처리 묶음(원장 헤더)", [
    ID(),
    C("transaction_no", "varchar(30)", True, comment="처리 번호"),
    C("transaction_type", "varchar(30)", True, comment="처리 유형"),
    C("business_date", "date", True, comment="업무 날짜"),
    C("status", "varchar(10)", True, "'DRAFT'", "상태(임시/확정)"),
    C("request_id", "varchar(64)", True, comment="중복 요청 방지 키"),
    C("related_transaction_id", "uuid", comment="취소·정정 원본 묶음"),
    C("source_type", "varchar(30)", comment="출처 유형"),
    C("source_id", "uuid", comment="출처 ID"),
    C("counterparty_partner_id", "uuid", comment="상대 거래처"),
    C("reason_code", "varchar(30)", comment="사유 코드"),
    C("reason", "text", comment="사유"),
    C("reference_no", "varchar(100)", comment="외부 문서번호"),
    C("approved_by", "uuid", comment="승인자"),
    C("approved_at", "timestamptz", comment="승인 시각"),
    C("note", "text", comment="비고"),
    C("created_at", "timestamptz", True, "now()", "생성 시각"),
    C("created_by", "uuid", True, comment="생성자"),
    C("posted_at", "timestamptz", comment="확정 시각"),
    C("posted_by", "uuid", comment="확정자")],
  uniques=[["transaction_no"], ["request_id"]],
  checks=[inlist("transaction_type", TX_TYPES), inlist("status", ["DRAFT", "POSTED"])],
  fks=[("related_transaction_id", "stock_transactions"),
       ("counterparty_partner_id", "partners")])

T("inventory", "ledger_entries", "재고 원장(INSERT 전용)", [
    ID(),
    C("transaction_id", "uuid", True, comment="처리 묶음"),
    C("line_no", "integer", True, comment="행 번호"),
    C("product_id", "uuid", True, comment="제품"),
    C("location_id", "uuid", True, comment="위치"),
    C("stock_condition", "varchar(20)", True, comment="재고 상태"),
    *OWNER(),
    C("quantity_delta", "integer", True, comment="수량 증감(+입고/-출고)"),
    C("business_date", "date", True, comment="업무 날짜"),
    C("equipment_id", "uuid", comment="개별 장비"),
    C("pair_id", "uuid", comment="쌍 처리 묶음 ID"),
    C("reversal_of_entry_id", "uuid", comment="취소 대상 원장 행"),
    C("trade_line_id", "uuid", comment="연결 거래 품목(참조)"),
    C("lot_no", "varchar(50)", comment="로트 번호"),
    C("item_code_snapshot", "varchar(50)", True, comment="처리 당시 Item Code"),
    C("product_name_snapshot", "varchar(200)", True, comment="처리 당시 제품명"),
    C("note", "text", comment="비고"),
    C("created_at", "timestamptz", True, "now()", "생성 시각"),
    C("created_by", "uuid", True, comment="생성자")],
  uniques=[["transaction_id", "line_no"], ["reversal_of_entry_id"]],
  checks=[inlist("stock_condition", CONDITIONS), inlist("owner_type", OWNER_TYPES),
          OWNER_CHECK, "quantity_delta <> 0"],
  fks=[("transaction_id", "stock_transactions"), ("product_id", "products"),
       ("location_id", "locations"), ("owner_partner_id", "partners"),
       ("equipment_id", "equipment"), ("reversal_of_entry_id", "ledger_entries")],
  indexes=[["product_id", "location_id", "stock_condition", "owner_type", "owner_partner_id",
            "business_date"]],
  pg_extra=["""CREATE OR REPLACE FUNCTION inventory.fn_ledger_entries_append_only()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    RAISE EXCEPTION 'inventory.ledger_entries is append-only (% not allowed)', TG_OP;
END;
$$;""",
            """CREATE TRIGGER trg_ledger_entries_append_only
    BEFORE UPDATE OR DELETE ON inventory.ledger_entries
    FOR EACH ROW EXECUTE FUNCTION inventory.fn_ledger_entries_append_only();"""])

T("inventory", "stock_balances", "현재 재고(잠금 대상)", [
    ID(),
    C("product_id", "uuid", True, comment="제품"),
    C("location_id", "uuid", True, comment="위치"),
    C("stock_condition", "varchar(20)", True, comment="재고 상태"),
    *OWNER(),
    C("quantity", "integer", True, "0", "수량"),
    C("updated_at", "timestamptz", True, "now()", "갱신 시각")],
  checks=[inlist("stock_condition", CONDITIONS), inlist("owner_type", OWNER_TYPES),
          OWNER_CHECK, "quantity >= 0"],
  fks=[("product_id", "products"), ("location_id", "locations"),
       ("owner_partner_id", "partners")],
  pg_extra=["ALTER TABLE inventory.stock_balances ADD CONSTRAINT ux_stock_balances_key "
            "UNIQUE NULLS NOT DISTINCT (product_id, location_id, stock_condition, owner_type, "
            "owner_partner_id);"])

T("inventory", "period_closings", "월 마감", [
    ID(),
    C("period", "char(7)", True, comment="기간(YYYY-MM)"),
    C("status", "varchar(10)", True, "'OPEN'", "상태"),
    C("closed_at", "timestamptz", comment="마감 시각"),
    C("closed_by", "uuid", comment="마감자"),
    C("snapshot_version", "integer", True, "0", "스냅샷 버전")],
  uniques=[["period"]], checks=[inlist("status", ["OPEN", "CLOSED"])])

T("inventory", "period_closing_events", "마감·해제 이력", [
    ID(),
    C("period", "char(7)", True, comment="기간"),
    C("action", "varchar(10)", True, comment="동작(마감/해제)"),
    C("reason", "text", comment="사유"),
    C("acted_by", "uuid", True, comment="처리자"),
    C("acted_at", "timestamptz", True, "now()", "처리 시각")],
  checks=[inlist("action", ["CLOSE", "REOPEN"])],
  fks=[("period", "period_closings", "period")])

T("inventory", "monthly_stock_snapshots", "월말 재고 스냅샷", [
    ID(),
    C("period", "char(7)", True, comment="기간"),
    C("snapshot_version", "integer", True, comment="스냅샷 버전"),
    C("product_id", "uuid", True, comment="제품"),
    C("location_id", "uuid", True, comment="위치"),
    C("stock_condition", "varchar(20)", True, comment="재고 상태"),
    *OWNER(),
    C("quantity", "integer", True, comment="수량")],
  fks=[("product_id", "products"), ("location_id", "locations"),
       ("owner_partner_id", "partners")],
  pg_extra=["ALTER TABLE inventory.monthly_stock_snapshots ADD CONSTRAINT ux_monthly_stock_snapshots_key "
            "UNIQUE NULLS NOT DISTINCT (period, snapshot_version, product_id, location_id, "
            "stock_condition, owner_type, owner_partner_id);"])

T("inventory", "stock_counts", "재고 실사", [
    ID(),
    C("count_no", "varchar(30)", True, comment="실사 번호"),
    C("scope_type", "varchar(20)", True, comment="범위 유형"),
    C("base_date", "date", True, comment="실사 기준일"),
    C("assignee_id", "uuid", True, comment="담당자"),
    C("status", "varchar(20)", True, "'PREPARED'", "상태"),
    C("started_at", "timestamptz", comment="시작 시각"),
    C("approved_by", "uuid", comment="승인자"),
    C("approved_at", "timestamptz", comment="승인 시각"),
    C("adjustment_transaction_id", "uuid", comment="실사 조정 묶음"),
    C("note", "text", comment="비고"),
    *AUD()],
  uniques=[["count_no"]],
  checks=[inlist("scope_type", ["LOCATION", "PRODUCT"]),
          inlist("status", ["PREPARED", "IN_PROGRESS", "REVIEW", "APPROVED", "CANCELLED"])],
  fks=[("adjustment_transaction_id", "stock_transactions")])

T("inventory", "stock_count_scopes", "실사 잠금 범위", [
    ID(),
    C("count_id", "uuid", True, comment="실사"),
    C("location_id", "uuid", comment="위치"),
    C("product_id", "uuid", comment="제품")],
  checks=["location_id IS NOT NULL OR product_id IS NOT NULL"],
  fks=[("count_id", "stock_counts"), ("location_id", "locations"), ("product_id", "products")])

T("inventory", "stock_count_lines", "실사 품목", [
    ID(),
    C("count_id", "uuid", True, comment="실사"),
    C("product_id", "uuid", True, comment="제품"),
    C("location_id", "uuid", True, comment="위치"),
    C("stock_condition", "varchar(20)", True, comment="재고 상태"),
    *OWNER(),
    C("book_quantity", "integer", True, comment="장부 수량(시작 시점)"),
    C("counted_quantity", "integer", comment="실물 수량"),
    C("recounted", "boolean", True, "false", "재실사 여부"),
    C("note", "text", comment="비고")],
  checks=[inlist("stock_condition", CONDITIONS), inlist("owner_type", OWNER_TYPES), OWNER_CHECK],
  fks=[("count_id", "stock_counts"), ("product_id", "products"), ("location_id", "locations"),
       ("owner_partner_id", "partners")])

T("inventory", "stock_count_serials", "실사 시리얼 대조", [
    ID(),
    C("count_id", "uuid", True, comment="실사"),
    C("line_id", "uuid", True, comment="실사 품목"),
    C("serial_no", "varchar(100)", True, comment="시리얼"),
    C("equipment_id", "uuid", comment="장비"),
    C("result", "varchar(20)", True, comment="대조 결과")],
  checks=[inlist("result", ["MATCHED", "MISSING", "UNEXPECTED"])],
  fks=[("count_id", "stock_counts"), ("line_id", "stock_count_lines"),
       ("equipment_id", "equipment")])

# ================================================================ equipment
T("equipment", "equipment", "개별 장비(시리얼)", [
    ID(),
    C("product_id", "uuid", True, comment="제품"),
    C("serial_no", "varchar(100)", comment="시리얼 번호(미확인 시 NULL)"),
    C("serial_status", "varchar(20)", True, "'CONFIRMED'", "시리얼 확인 상태"),
    C("status", "varchar(30)", True, comment="장비 상태"),
    C("current_location_id", "uuid", comment="현재 위치"),
    *OWNER(),
    C("project_id", "uuid", comment="프로젝트"),
    C("delivered_partner_id", "uuid", comment="납품처"),
    C("replaced_by_equipment_id", "uuid", comment="교체된 새 장비"),
    C("origin_type", "varchar(30)", True, "'LEDGER'", "생성 경로(원장/기준일 이전 납품)"),
    C("last_event_date", "date", True, comment="마지막 처리 날짜"),
    *AUD()],
  checks=[inlist("serial_status", ["CONFIRMED", "UNKNOWN"]), inlist("status", EQUIP_STATUS),
          inlist("owner_type", OWNER_TYPES), OWNER_CHECK,
          "serial_status = 'UNKNOWN' OR serial_no IS NOT NULL",
          inlist("origin_type", ["LEDGER", "PRE_CUTOVER_DELIVERY"])],
  fks=[("product_id", "products"), ("current_location_id", "locations"),
       ("owner_partner_id", "partners"), ("project_id", "projects"),
       ("delivered_partner_id", "partners"), ("replaced_by_equipment_id", "equipment")],
  pg_extra=["CREATE UNIQUE INDEX ux_equipment_product_serial ON equipment.equipment "
            "(product_id, serial_no) WHERE serial_no IS NOT NULL;"])

T("equipment", "equipment_events", "장비 이력", [
    ID(),
    C("equipment_id", "uuid", True, comment="장비"),
    C("event_type", "varchar(30)", True, comment="이벤트 유형"),
    C("business_date", "date", True, comment="업무 날짜"),
    C("from_status", "varchar(30)", comment="이전 상태"),
    C("to_status", "varchar(30)", comment="이후 상태"),
    C("from_location_id", "uuid", comment="출발 위치"),
    C("to_location_id", "uuid", comment="도착 위치"),
    C("old_value", "text", comment="이전 값(시리얼 수정 등)"),
    C("new_value", "text", comment="새 값(시리얼 수정 등)"),
    C("ledger_entry_id", "uuid", comment="원장 행"),
    C("source_type", "varchar(30)", comment="출처 유형"),
    C("source_id", "uuid", comment="출처 ID"),
    C("note", "text", comment="비고"),
    C("created_at", "timestamptz", True, "now()", "생성 시각"),
    C("created_by", "uuid", True, comment="생성자")],
  fks=[("equipment_id", "equipment"), ("from_location_id", "locations"),
       ("to_location_id", "locations"), ("ledger_entry_id", "ledger_entries")],
  indexes=[["equipment_id", "business_date"]])

T("equipment", "warranties", "보증", [
    ID(),
    C("equipment_id", "uuid", True, comment="장비"),
    C("status", "varchar(20)", True, "'UNKNOWN'", "확인 상태"),
    C("start_date", "date", comment="보증 시작일"),
    C("end_date", "date", comment="보증 만료일"),
    C("basis", "varchar(20)", comment="시작 기준"),
    C("inherited_from_equipment_id", "uuid", comment="승계 원 장비"),
    C("note", "text", comment="비고"),
    *AUD()],
  uniques=[["equipment_id"]],
  checks=[inlist("status", ["CONFIRMED", "UNKNOWN"]),
          "end_date IS NULL OR start_date IS NULL OR end_date >= start_date",
          "basis IS NULL OR " + inlist("basis", ["DELIVERY", "MANUFACTURER", "PURCHASE", "MANUAL"])],
  fks=[("equipment_id", "equipment"), ("inherited_from_equipment_id", "equipment")])

T("equipment", "warranty_changes", "보증 변경 이력", [
    ID(),
    C("warranty_id", "uuid", True, comment="보증"),
    C("old_start_date", "date", comment="이전 시작일"),
    C("old_end_date", "date", comment="이전 만료일"),
    C("new_start_date", "date", comment="변경 시작일"),
    C("new_end_date", "date", comment="변경 만료일"),
    C("reason", "text", comment="사유"),
    C("changed_by", "uuid", True, comment="변경자"),
    C("changed_at", "timestamptz", True, "now()", "변경 시각")],
  fks=[("warranty_id", "warranties")])

# ================================================================ project
T("project", "projects", "프로젝트", [
    ID(),
    C("project_code", "varchar(30)", True, comment="프로젝트 코드"),
    C("project_name", "varchar(200)", True, comment="프로젝트명"),
    C("customer_partner_id", "uuid", comment="주 고객사"),
    C("status", "varchar(20)", True, "'ACTIVE'", "상태"),
    C("note", "text", comment="비고"),
    *AUD(), *DEL()],
  uniques=[["project_code"]],
  checks=[inlist("status", ["ACTIVE", "COMPLETED", "CANCELLED"])],
  fks=[("customer_partner_id", "partners")])

T("project", "trade_documents", "거래 문서(발주서·매출·선발주)", [
    ID(),
    C("project_id", "uuid", True, comment="프로젝트"),
    C("trade_type", "varchar(20)", True, comment="거래 구분"),
    C("partner_id", "uuid", True, comment="거래처"),
    C("document_no", "varchar(50)", comment="거래처 문서번호"),
    C("document_date", "date", True, comment="문서 일자"),
    C("status", "varchar(20)", True, "'DRAFT'", "상태"),
    C("copied_from_document_id", "uuid", comment="복사 원본 문서"),
    C("note", "text", comment="비고"),
    *AUD(), *DEL()],
  checks=[inlist("trade_type", ["PURCHASE", "SALES", "PRE_ORDER"]),
          inlist("status", ["DRAFT", "CONFIRMED", "COMPLETED", "CANCELLED"])],
  fks=[("project_id", "projects"), ("partner_id", "partners"),
       ("copied_from_document_id", "trade_documents")],
  pg_extra=["CREATE UNIQUE INDEX ux_trade_documents_partner_docno ON project.trade_documents "
            "(partner_id, document_no) WHERE deleted_at IS NULL AND document_no IS NOT NULL;"])

T("project", "trade_lines", "거래 품목", [
    ID(),
    C("document_id", "uuid", True, comment="거래 문서"),
    C("line_no", "integer", True, comment="행 번호"),
    C("product_id", "uuid", True, comment="제품"),
    C("quantity", "integer", True, comment="문서 수량"),
    C("opening_fulfilled_quantity", "integer", True, "0", "기준일 이전 처리 수량"),
    C("fulfilled_quantity", "integer", True, "0", "처리된 수량"),
    C("closed_quantity", "integer", True, "0", "잔량 마감 수량"),
    C("closed_reason", "text", comment="잔량 마감 사유"),
    C("closed_by", "uuid", comment="잔량 마감자"),
    C("closed_at", "timestamptz", comment="잔량 마감 시각"),
    C("route", "varchar(20)", True, "'WAREHOUSE'", "경로(창고 경유/직납)"),
    C("note", "text", comment="비고"),
    *AUD()],
  uniques=[["document_id", "line_no"]],
  checks=["quantity > 0", "fulfilled_quantity >= 0", "closed_quantity >= 0",
          "opening_fulfilled_quantity + fulfilled_quantity + closed_quantity <= quantity",
          inlist("route", ["WAREHOUSE", "DIRECT"]),
          "opening_fulfilled_quantity >= 0"],
  fks=[("document_id", "trade_documents"), ("product_id", "products")])

T("project", "trade_document_changes", "거래 문서 변경 이력", [
    ID(),
    C("document_id", "uuid", True, comment="거래 문서"),
    C("line_id", "uuid", comment="거래 품목"),
    C("field_name", "varchar(50)", True, comment="변경 항목"),
    C("old_value", "text", comment="이전 값"),
    C("new_value", "text", comment="새 값"),
    C("reason", "text", comment="사유"),
    C("changed_by", "uuid", True, comment="변경자"),
    C("changed_at", "timestamptz", True, "now()", "변경 시각")],
  fks=[("document_id", "trade_documents"), ("line_id", "trade_lines")])

# ================================================================ allocation
T("allocation", "allocations", "배정", [
    ID(),
    C("product_id", "uuid", True, comment="제품"),
    C("quantity", "integer", True, comment="배정 수량"),
    C("consumed_quantity", "integer", True, "0", "소진 수량"),
    C("target_type", "varchar(20)", True, comment="배정 대상 유형"),
    C("project_id", "uuid", comment="대상 프로젝트"),
    C("loan_document_id", "uuid", comment="대상 차입(상환용)"),
    C("source_type", "varchar(20)", True, comment="배정 원천(보유/예정)"),
    C("source_trade_line_id", "uuid", comment="예정 물량 발주 품목"),
    C("owner_type", "varchar(20)", comment="보유 재고 소유 구분"),
    C("owner_partner_id", "uuid", comment="타사 소유 업체"),
    C("equipment_id", "uuid", comment="개별 장비"),
    C("status", "varchar(20)", True, "'ACTIVE'", "상태"),
    C("note", "text", comment="비고"),
    *AUD()],
  checks=["quantity > 0", "consumed_quantity >= 0 AND consumed_quantity <= quantity",
          inlist("target_type", ["PROJECT", "LOAN_REPAY"]),
          "(target_type = 'PROJECT' AND project_id IS NOT NULL) OR "
          "(target_type = 'LOAN_REPAY' AND loan_document_id IS NOT NULL)",
          inlist("source_type", ["STOCK", "RECEIVED", "PLANNED"]),
          "source_type = 'STOCK' OR source_trade_line_id IS NOT NULL",
          "owner_type IS NULL OR " + inlist("owner_type", OWNER_TYPES),
          inlist("status", ["ACTIVE", "RELEASED", "CONSUMED"])],
  fks=[("product_id", "products"), ("project_id", "projects"),
       ("loan_document_id", "loan_documents"), ("source_trade_line_id", "trade_lines"),
       ("owner_partner_id", "partners"), ("equipment_id", "equipment")])

T("allocation", "allocation_events", "배정 이력", [
    ID(),
    C("allocation_id", "uuid", True, comment="배정"),
    C("action", "varchar(20)", True, comment="동작"),
    C("quantity", "integer", True, comment="수량"),
    C("reason", "text", comment="사유"),
    C("acted_by", "uuid", True, comment="처리자"),
    C("acted_at", "timestamptz", True, "now()", "처리 시각")],
  checks=[inlist("action", ["ALLOCATE", "CHANGE", "RELEASE", "CONSUME", "CONVERT"])],
  fks=[("allocation_id", "allocations")])

# ================================================================ delivery
T("delivery", "deliveries", "납품 회차", [
    ID(),
    C("delivery_no", "varchar(30)", True, comment="납품 번호"),
    C("project_id", "uuid", True, comment="프로젝트"),
    C("sales_document_id", "uuid", comment="매출 문서"),
    C("customer_partner_id", "uuid", True, comment="고객사"),
    C("delivery_date", "date", True, comment="납품일"),
    C("place", "varchar(300)", comment="납품 장소"),
    C("route", "varchar(20)", True, "'WAREHOUSE'", "경로(창고 경유/직납)"),
    C("bundle_id", "uuid", comment="구성 묶음"),
    C("bundle_set_quantity", "integer", comment="세트 수"),
    C("status", "varchar(20)", True, "'DRAFT'", "상태"),
    C("transaction_id", "uuid", comment="창고 출고 묶음"),
    C("note", "text", comment="비고"),
    *AUD()],
  uniques=[["delivery_no"]],
  checks=[inlist("route", ["WAREHOUSE", "DIRECT"]),
          inlist("status", ["DRAFT", "POSTED", "CANCELLED"]),
          "(bundle_id IS NULL AND bundle_set_quantity IS NULL) OR (bundle_id IS NOT NULL AND bundle_set_quantity > 0)"],
  fks=[("project_id", "projects"), ("sales_document_id", "trade_documents"),
       ("customer_partner_id", "partners"), ("bundle_id", "bundles"),
       ("transaction_id", "stock_transactions")])

T("delivery", "delivery_lines", "납품 품목", [
    ID(),
    C("delivery_id", "uuid", True, comment="납품 회차"),
    C("line_no", "integer", True, comment="행 번호"),
    C("product_id", "uuid", True, comment="제품"),
    C("quantity", "integer", True, comment="납품 수량"),
    C("sales_line_id", "uuid", comment="매출 품목"),
    C("purchase_line_id", "uuid", comment="직납 발주 품목"),
    C("loan_line_id", "uuid", comment="차입 직납 대차 품목"),
    C("equipment_id", "uuid", comment="개별 장비"),
    C("returned_quantity", "integer", True, "0", "반품 수량"),
    C("note", "text", comment="비고")],
  uniques=[["delivery_id", "line_no"]],
  checks=["quantity > 0", "returned_quantity >= 0 AND returned_quantity <= quantity"],
  fks=[("delivery_id", "deliveries"), ("product_id", "products"),
       ("sales_line_id", "trade_lines"), ("purchase_line_id", "trade_lines"),
       ("loan_line_id", "loan_lines"), ("equipment_id", "equipment")])

T("delivery", "delivery_returns", "고객 반품", [
    ID(),
    C("delivery_line_id", "uuid", comment="납품 품목"),
    C("equipment_id", "uuid", comment="기준일 이전 납품 장비"),
    C("quantity", "integer", True, comment="반품 수량"),
    C("return_date", "date", True, comment="반품일"),
    C("transaction_id", "uuid", comment="반품 입고 묶음"),
    C("reason", "text", comment="사유"),
    *AUD()],
  checks=["quantity > 0",
          "delivery_line_id IS NOT NULL OR (equipment_id IS NOT NULL AND quantity = 1)"],
  fks=[("delivery_line_id", "delivery_lines"), ("equipment_id", "equipment"),
       ("transaction_id", "stock_transactions")])

# ================================================================ loan
T("loan", "loan_documents", "대차 문서(차입·대여)", [
    ID(),
    C("loan_no", "varchar(30)", True, comment="대차 번호"),
    C("direction", "varchar(10)", True, comment="방향(차입/대여)"),
    C("partner_id", "uuid", True, comment="상대 업체"),
    C("project_id", "uuid", comment="관련 프로젝트"),
    C("settlement_method", "varchar(20)", True, comment="정산 방식"),
    C("due_date", "date", comment="상환·회수 기한"),
    C("status", "varchar(20)", True, "'OPEN'", "상태"),
    C("converted_trade_document_id", "uuid", comment="전환 거래 문서"),
    C("approved_by", "uuid", comment="승인자"),
    C("approved_at", "timestamptz", comment="승인 시각"),
    C("note", "text", comment="비고"),
    *AUD(), *DEL()],
  uniques=[["loan_no"]],
  checks=[inlist("direction", ["IN", "OUT"]),
          inlist("settlement_method", ["IN_KIND", "CONVERT", "RETURN_ORIGINAL"]),
          inlist("status", ["OPEN", "SETTLED", "CANCELLED"])],
  fks=[("partner_id", "partners"), ("project_id", "projects"),
       ("converted_trade_document_id", "trade_documents")])

T("loan", "loan_lines", "대차 품목", [
    ID(),
    C("loan_id", "uuid", True, comment="대차 문서"),
    C("line_no", "integer", True, comment="행 번호"),
    C("product_id", "uuid", True, comment="제품"),
    C("quantity", "integer", True, comment="수량"),
    C("moved_quantity", "integer", True, "0", "받은(차입)·내보낸(대여) 수량"),
    C("settled_quantity", "integer", True, "0", "정산 수량"),
    C("equipment_id", "uuid", comment="개별 장비"),
    C("note", "text", comment="비고")],
  uniques=[["loan_id", "line_no"]],
  checks=["quantity > 0", "settled_quantity >= 0 AND settled_quantity <= quantity",
          "moved_quantity >= 0 AND moved_quantity <= quantity"],
  fks=[("loan_id", "loan_documents"), ("product_id", "products"),
       ("equipment_id", "equipment")])

T("loan", "loan_settlements", "대차 정산 기록", [
    ID(),
    C("loan_line_id", "uuid", True, comment="대차 품목"),
    C("settled_date", "date", True, comment="정산 날짜"),
    C("method", "varchar(20)", True, comment="정산 방식"),
    C("quantity", "integer", True, comment="정산 수량"),
    C("settled_product_id", "uuid", True, comment="실제 주고받은 제품"),
    C("equipment_id", "uuid", comment="개별 장비"),
    C("status", "varchar(20)", True, "'POSTED'", "상태"),
    C("transaction_id", "uuid", comment="처리 묶음"),
    C("trade_document_id", "uuid", comment="전환 거래 문서"),
    C("note", "text", comment="비고"),
    *AUD()],
  checks=["quantity > 0",
          inlist("method", ["IN_KIND", "CONVERT", "RETURN_ORIGINAL"]),
          inlist("status", ["PENDING_APPROVAL", "POSTED", "REJECTED", "CANCELLED"]),
          "method <> 'CONVERT' OR trade_document_id IS NOT NULL",
          "equipment_id IS NULL OR quantity = 1"],
  fks=[("loan_line_id", "loan_lines"), ("settled_product_id", "products"),
       ("equipment_id", "equipment"), ("transaction_id", "stock_transactions"),
       ("trade_document_id", "trade_documents")])

T("loan", "loan_document_changes", "대차 문서 변경 이력", [
    ID(),
    C("loan_id", "uuid", True, comment="대차 문서"),
    C("line_id", "uuid", comment="대차 품목"),
    C("field_name", "varchar(50)", True, comment="변경 항목"),
    C("old_value", "text", comment="이전 값"),
    C("new_value", "text", comment="새 값"),
    C("reason", "text", comment="사유"),
    C("changed_by", "uuid", True, comment="변경자"),
    C("changed_at", "timestamptz", True, "now()", "변경 시각")],
  fks=[("loan_id", "loan_documents"), ("line_id", "loan_lines")])

# ================================================================ trash
T("trash", "trash_events", "삭제·복구 이력", [
    ID(),
    C("entity_type", "varchar(50)", True, comment="대상 유형"),
    C("entity_id", "uuid", True, comment="대상 ID"),
    C("action", "varchar(10)", True, comment="동작(삭제/복구)"),
    C("reason", "text", comment="사유"),
    C("acted_by", "uuid", True, comment="처리자"),
    C("acted_at", "timestamptz", True, "now()", "처리 시각")],
  checks=[inlist("action", ["DELETE", "RESTORE"])],
  indexes=[["entity_type", "entity_id"]])


# ================================================================ cost
def MONEY(amount_col, amount_type, krw_col):
    return [C(amount_col, amount_type, True, comment="금액" if amount_col == "amount" else "단가"),
            C("currency", "char(3)", True, "'KRW'", "통화"),
            C("exchange_rate", "numeric(18,6)", True, "1", "적용 환율"),
            C("exchange_rate_date", "date", comment="환율 기준일"),
            C(krw_col, amount_type, True, comment="원화 환산")]


T("cost", "currencies", "통화", [
    C("code", "char(3)", True, comment="통화 코드(ISO 4217)"),
    C("name", "varchar(50)", True, comment="통화명"),
    C("minor_unit", "smallint", True, comment="소수 자리수"),
    C("is_active", "boolean", True, "false", "사용 여부")],
  pk=("code",), checks=["minor_unit BETWEEN 0 AND 4"])

T("cost", "line_prices", "거래 품목 단가", [
    C("trade_line_id", "uuid", True, comment="거래 품목"),
    *MONEY("unit_price", "numeric(19,4)", "unit_price_krw"),
    C("tax_type", "varchar(20)", comment="과세 구분"),
    C("attribution_basis", "varchar(20)", True, "'DOCUMENT_DATE'", "금액 귀속 기준"),
    C("attribution_date", "date", comment="직접 입력한 귀속일(MANUAL일 때)"),
    *AUD()],
  pk=("trade_line_id",), checks=["exchange_rate > 0", "currency = 'KRW' OR exchange_rate_date IS NOT NULL",
          inlist("attribution_basis", ["DOCUMENT_DATE", "FULFILLED_DATE", "MANUAL"]), "(attribution_basis = 'MANUAL') = (attribution_date IS NOT NULL)"],
  fks=[("trade_line_id", "trade_lines"), ("currency", "currencies", "code")])

T("cost", "extra_costs", "부대비용", [
    ID(),
    C("project_id", "uuid", True, comment="프로젝트"),
    C("cost_type", "varchar(20)", True, comment="비용 유형"),
    *MONEY("amount", "numeric(18,2)", "amount_krw"),
    C("cost_date", "date", True, comment="비용 발생일"),
    C("trade_document_id", "uuid", comment="관련 거래 문서"),
    C("loan_document_id", "uuid", comment="관련 대차 문서"),
    C("note", "text", comment="비고"),
    C("attribution_basis", "varchar(20)", True, "'COST_DATE'", "금액 귀속 기준"),
    C("attribution_date", "date", comment="직접 입력한 귀속일(MANUAL일 때)"),
    *AUD(), *DEL()],
  checks=[inlist("cost_type", ["SHIPPING", "INSTALL", "RENTAL", "OTHER"]), "exchange_rate > 0",
          "cost_type <> 'RENTAL' OR loan_document_id IS NOT NULL", "currency = 'KRW' OR exchange_rate_date IS NOT NULL",
          inlist("attribution_basis", ["COST_DATE", "MANUAL"]), "(attribution_basis = 'MANUAL') = (attribution_date IS NOT NULL)"],
  fks=[("project_id", "projects"), ("currency", "currencies", "code"),
       ("trade_document_id", "trade_documents"), ("loan_document_id", "loan_documents")])

T("cost", "loan_fees", "대여료", [
    C("loan_document_id", "uuid", True, comment="대차 문서"),
    *MONEY("amount", "numeric(18,2)", "amount_krw"),
    C("attribution_basis", "varchar(20)", True, "'SETTLED_DATE'", "금액 귀속 기준"),
    C("attribution_date", "date", comment="직접 입력한 귀속일(MANUAL일 때)"),
    *AUD()],
  pk=("loan_document_id",), checks=["exchange_rate > 0", "currency = 'KRW' OR exchange_rate_date IS NOT NULL",
          inlist("attribution_basis", ["SETTLED_DATE", "DUE_DATE", "MANUAL"]), "(attribution_basis = 'MANUAL') = (attribution_date IS NOT NULL)"],
  fks=[("loan_document_id", "loan_documents"), ("currency", "currencies", "code")])

T("cost", "opening_costs", "초기 재고 단가", [
    C("ledger_entry_id", "uuid", True, comment="초기 재고 원장 행"),
    *MONEY("unit_cost", "numeric(19,4)", "unit_cost_krw"),
    C("note", "text", comment="평가 근거"),
    C("attribution_basis", "varchar(20)", True, "'CUTOVER_DATE'", "금액 귀속 기준"),
    C("attribution_date", "date", comment="직접 입력한 귀속일(MANUAL일 때)"),
    *AUD()],
  pk=("ledger_entry_id",), checks=["unit_cost >= 0", "exchange_rate > 0", "currency = 'KRW' OR exchange_rate_date IS NOT NULL",
          inlist("attribution_basis", ["CUTOVER_DATE", "MANUAL"]), "(attribution_basis = 'MANUAL') = (attribution_date IS NOT NULL)"],
  fks=[("ledger_entry_id", "ledger_entries"), ("currency", "currencies", "code")])

T("cost", "cost_changes", "금액 변경 이력", [
    ID(),
    C("target_type", "varchar(20)", True, comment="대상 유형"),
    C("target_id", "uuid", True, comment="대상 ID(거래 품목·부대비용·대차 문서·원장 행)"),
    C("field_name", "varchar(50)", True, comment="바뀐 항목"),
    C("old_value", "text", comment="이전 값"),
    C("new_value", "text", comment="새 값"),
    C("reason", "text", comment="사유"),
    C("changed_by", "uuid", True, comment="변경자"),
    C("changed_at", "timestamptz", True, "now()", "변경 시각")],
  checks=[inlist("target_type", ["LINE_PRICE", "EXTRA_COST", "LOAN_FEE", "OPENING_COST"])],
  indexes=[["target_type", "target_id"]])

# ================================================================ importing
ATTACH_TARGETS = ["TRADE_DOCUMENT"]
ATTACH_TYPES = ["application/pdf", "image/jpeg", "image/png"]
T("importing", "files", "첨부 파일(증빙)", [
    ID(),
    C("target_type", "varchar(30)", True, comment="첨부 대상 종류"),
    C("target_id", "uuid", True, comment="첨부 대상 ID"),
    C("original_name", "varchar(300)", True, comment="원본 파일명"),
    C("content_type", "varchar(100)", True, comment="파일 형식(MIME)"),
    C("storage_key", "varchar(500)", True, comment="저장 위치 키(최상위 폴더 기준 상대 경로)"),
    C("content_hash", "varchar(64)", True, comment="내용 해시(SHA-256, 같은 내용 경고용)"),
    C("size_bytes", "bigint", True, comment="크기(바이트)"),
    C("uploaded_by", "uuid", True, comment="올린 사람"),
    C("uploaded_at", "timestamptz", True, "now()", "올린 시각"),
    C("note", "text", comment="비고"),
    *DEL()],
  uniques=[["storage_key"]],
  checks=[inlist("target_type", ATTACH_TARGETS),
          inlist("content_type", ATTACH_TYPES),
          "size_bytes > 0 AND size_bytes <= 20971520"],
  indexes=[["target_type", "target_id"], ["content_hash"]])

# ================================================================ common
T("common", "idempotency_keys", "중복 요청 키", [
    C("idempotency_key", "varchar(64)", True, comment="중복 요청 키"),
    C("user_id", "uuid", True, comment="요청자"),
    C("action", "varchar(100)", True, comment="API 동작"),
    C("request_hash", "varchar(64)", True, comment="요청 내용 해시"),
    C("status", "varchar(20)", True, "'IN_PROGRESS'", "처리 상태"),
    C("response_status", "integer", comment="처음 응답 HTTP 상태"),
    C("response_body", "jsonb", comment="처음 응답 본문"),
    C("created_at", "timestamptz", True, "now()", "받은 시각"),
    C("completed_at", "timestamptz", comment="끝난 시각")],
  pk=("idempotency_key",),
  checks=[inlist("status", ["IN_PROGRESS", "DONE"]),
          "status = 'IN_PROGRESS' OR (response_status IS NOT NULL AND completed_at IS NOT NULL)"],
  indexes=[["created_at"]])

# ================================================================ admin
APPROVAL_TYPES = ["DISPOSAL", "LOAN_OUT", "EQUIVALENT_SETTLEMENT", "COUNT_DIFFERENCE"]
CONFIRM_TYPES = ["UNPLANNED_RECEIPT", "SERIAL_CHANGE", "LOAN_DUE_CHANGE"]
T("admin", "review_requests", "승인·확인 요청", [
    ID(),
    C("request_type", "varchar(30)", True, comment="요청 종류"),
    C("target_type", "varchar(30)", True, comment="대상 유형"),
    C("target_id", "uuid", True, comment="대상 ID"),
    C("status", "varchar(20)", True, "'PENDING'", "상태"),
    C("summary", "text", comment="요약"),
    C("requested_by", "uuid", True, comment="요청자"),
    C("requested_at", "timestamptz", True, "now()", "요청 시각"),
    C("decided_by", "uuid", comment="처리자"),
    C("decided_at", "timestamptz", comment="처리 시각"),
    C("decision_reason", "text", comment="반려 사유"),
    C("version", "integer", True, "0", "버전(낙관적 잠금)")],
  checks=[inlist("request_type", APPROVAL_TYPES + CONFIRM_TYPES),
          inlist("status", ["PENDING", "APPROVED", "REJECTED", "CONFIRMED"]),
          "status NOT IN ('APPROVED', 'REJECTED') OR " + inlist("request_type", APPROVAL_TYPES),
          "status <> 'CONFIRMED' OR " + inlist("request_type", CONFIRM_TYPES),
          "status = 'PENDING' OR (decided_by IS NOT NULL AND decided_at IS NOT NULL)",
          "status <> 'REJECTED' OR decision_reason IS NOT NULL"],
  indexes=[["status", "request_type"]],
  pg_extra=["CREATE UNIQUE INDEX ux_review_requests_pending ON admin.review_requests "
            "(request_type, target_type, target_id) WHERE status = 'PENDING';"])

T("admin", "notifications", "알림", [
    ID(),
    C("recipient_user_id", "uuid", True, comment="받는 사람"),
    C("notification_type", "varchar(30)", True, comment="알림 종류"),
    C("title", "varchar(200)", True, comment="제목"),
    C("message", "text", comment="내용"),
    C("target_type", "varchar(30)", comment="연결 대상 유형"),
    C("target_id", "uuid", comment="연결 대상 ID"),
    C("created_at", "timestamptz", True, "now()", "생성 시각"),
    C("read_at", "timestamptz", comment="읽은 시각")],
  checks=[inlist("notification_type", ["REVIEW_REJECTED", "INTEGRITY_ALERT", "ALLOCATION_RELEASED", "WARRANTY_EXPIRING"])],
  indexes=[["recipient_user_id", "read_at"]])

T("admin", "integrity_check_results", "정합성 점검 결과", [
    ID(),
    C("check_code", "varchar(10)", True, comment="점검 항목(C1~)"),
    C("target_type", "varchar(30)", True, comment="어긋난 대상 유형"),
    C("target_key", "varchar(200)", True, comment="어긋난 대상 키"),
    C("detail", "jsonb", True, comment="어긋난 내용"),
    C("first_found_at", "timestamptz", True, "now()", "처음 발견 시각"),
    C("last_found_at", "timestamptz", True, "now()", "마지막 발견 시각"),
    C("resolved_at", "timestamptz", comment="해결 확인 시각")],
  checks=["resolved_at IS NULL OR resolved_at >= first_found_at"],
  pg_extra=["CREATE UNIQUE INDEX ux_integrity_check_results_open ON admin.integrity_check_results "
            "(check_code, target_type, target_key) WHERE resolved_at IS NULL;"])

SEED_PG = """-- ---------------------------------------------------------------- 초기 데이터
INSERT INTO cost.currencies (code, name, minor_unit, is_active) VALUES
    ('KRW', '대한민국 원', 0, true),
    ('USD', '미국 달러', 2, false);

INSERT INTO product.product_categories (code, name, sort_order) VALUES
    ('UPS', 'UPS', 1),
    ('RPDU', 'rPDU', 2),
    ('RACK', 'Rack', 3),
    ('KVM', 'KVM', 4),
    ('MONITORING_SENSOR', '모니터링 센서', 5),
    ('TH_SENSOR', '온습도 센서', 6),
    ('COOLING', '쿨링 시스템', 7);

INSERT INTO auth.roles (code, name) VALUES
    ('ADMIN', '관리자'),
    ('OPERATOR', '입력자'),
    ('VIEWER', '조회자');
"""

# ---------------------------------------------------------------- 생성기
BY_NAME = {t["name"]: t for t in TABLES}
assert len(BY_NAME) == len(TABLES), "table names must be unique across schemas"


def q(t):
    return f'{t["schema"]}.{t["name"]}'


def esc(s):
    return s.replace("'", "''")


def pg_type(c):
    return "bigint GENERATED ALWAYS AS IDENTITY" if c["type"] == "IDENTITY" else c["type"]


def gen_pg():
    out = ["-- ============================================================",
           "-- 자산관리 시스템 (Vertiv 제품·재고·물류 추적) PostgreSQL DDL",
           "-- 기준: 노션 '테이블 정의서' (2026-10-29)",
           "-- 대상: PostgreSQL 18 이상 (uuidv7(), UNIQUE NULLS NOT DISTINCT 사용)",
           "-- 생성 순서: 스키마 → 테이블 → 외래 키 → 인덱스·트리거 → 주석 → 초기 데이터",
           "-- ============================================================", "",
           "BEGIN;", ""]
    schemas = []
    for t in TABLES:
        if t["schema"] not in schemas:
            schemas.append(t["schema"])
    for s in schemas:
        out.append(f"CREATE SCHEMA IF NOT EXISTS {s};")
    out.append("")
    for t in TABLES:
        lines = []
        for c in t["cols"]:
            s = f'    {c["name"]} {pg_type(c)}'
            if c["nn"] and c["type"] != "IDENTITY":
                s += " NOT NULL"
            if c["default"] is not None:
                s += f' DEFAULT {c["default"]}'
            lines.append(s)
        lines.append(f'    CONSTRAINT pk_{t["name"]} PRIMARY KEY ({", ".join(t["pk"])})')
        for u in t["uniques"]:
            lines.append(f'    CONSTRAINT uq_{t["name"]}_{"_".join(u)} UNIQUE ({", ".join(u)})')
        for i, ck in enumerate(t["checks"], 1):
            lines.append(f'    CONSTRAINT ck_{t["name"]}_{i} CHECK ({ck})')
        out.append(f"CREATE TABLE {q(t)} (\n" + ",\n".join(lines) + "\n);\n")
    out.append("-- ---------------------------------------------------------------- 외래 키")
    for t in TABLES:
        for fk in t["fks"]:
            col, ref = fk[0], BY_NAME[fk[1]]
            refcol = fk[2] if len(fk) > 2 else ref["pk"][0]
            out.append(f'ALTER TABLE {q(t)} ADD CONSTRAINT fk_{t["name"]}_{col} '
                       f'FOREIGN KEY ({col}) REFERENCES {q(ref)} ({refcol});')
    out.append("")
    out.append("-- ---------------------------------------------------------------- 인덱스·부분 유니크·트리거")
    for t in TABLES:
        for idx in t["indexes"]:
            out.append(f'CREATE INDEX ix_{t["name"]}_{"_".join(idx)[:40]} ON {q(t)} ({", ".join(idx)});')
        for fk in t["fks"]:
            out.append(f'CREATE INDEX ix_{t["name"]}_{fk[0]} ON {q(t)} ({fk[0]});')
        for extra in t["pg_extra"]:
            out.append(extra)
    out.append("")
    out.append("-- ---------------------------------------------------------------- 주석")
    for t in TABLES:
        out.append(f"COMMENT ON TABLE {q(t)} IS '{esc(t['comment'])}';")
        for c in t["cols"]:
            if c["comment"]:
                out.append(f"COMMENT ON COLUMN {q(t)}.{c['name']} IS '{esc(c['comment'])}';")
    out.append("")
    out.append(SEED_PG)
    out.append("COMMIT;")
    out.append("")
    out.append("-- 운영 계정 권한 예시 (원장 보호):")
    out.append("-- REVOKE UPDATE, DELETE ON inventory.ledger_entries FROM app_user;")
    return "\n".join(out) + "\n"


def my_type(c):
    t = c["type"]
    if t == "IDENTITY":
        return "BIGINT AUTO_INCREMENT"
    m = {"timestamptz": "DATETIME(6)", "boolean": "BOOLEAN", "uuid": "CHAR(36)", "jsonb": "JSON",
         "text": "TEXT", "bigint": "BIGINT", "integer": "INT", "smallint": "SMALLINT",
         "date": "DATE"}
    if t in m:
        return m[t]
    return t.upper()


def my_default(c):
    d = c["default"]
    if d is None:
        return None
    if d == "now()":
        return "CURRENT_TIMESTAMP(6)"
    if d == "uuidv7()":
        return "(UUID())"
    return {"true": "TRUE", "false": "FALSE"}.get(d, d)


def gen_mysql():
    out = ["-- ============================================================",
           "-- 자산관리 시스템 DDL — ERDCloud 가져오기용 (MySQL 8 문법)",
           "-- 운영 DB는 PostgreSQL. 이 파일은 ERD 작성용으로 단순화한 버전이다.",
           "-- 차이: 스키마 접두어 생략(테이블 주석에 [스키마] 표기), 부분 유니크 인덱스·",
           "--       UNIQUE NULLS NOT DISTINCT·원장 보호 트리거·초기 데이터 생략",
           "-- ============================================================", "",
           "SET FOREIGN_KEY_CHECKS = 0;", ""]
    for t in TABLES:
        lines = []
        for c in t["cols"]:
            s = f'    `{c["name"]}` {my_type(c)}'
            s += " NOT NULL" if c["nn"] else " NULL"
            d = my_default(c)
            if d is not None:
                s += f" DEFAULT {d}"
            if c["comment"]:
                s += f" COMMENT '{esc(c['comment'])}'"
            lines.append(s)
        lines.append(f'    PRIMARY KEY ({", ".join("`"+p+"`" for p in t["pk"])})')
        for u in t["uniques"]:
            lines.append(f'    UNIQUE KEY `uq_{t["name"]}_{"_".join(u)}` ({", ".join("`"+x+"`" for x in u)})')
        for fk in t["fks"]:
            col, ref = fk[0], BY_NAME[fk[1]]
            refcol = fk[2] if len(fk) > 2 else ref["pk"][0]
            lines.append(f'    CONSTRAINT `fk_{t["name"]}_{col}` FOREIGN KEY (`{col}`) '
                         f'REFERENCES `{ref["name"]}` (`{refcol}`)')
        for i, ck in enumerate(t["checks"], 1):
            lines.append(f'    CONSTRAINT `ck_{t["name"]}_{i}` CHECK ({ck})')
        out.append(f"CREATE TABLE `{t['name']}` (\n" + ",\n".join(lines) +
                   f"\n) COMMENT = '[{t['schema']}] {esc(t['comment'])}';\n")
    out.append("SET FOREIGN_KEY_CHECKS = 1;")
    return "\n".join(out) + "\n"


if __name__ == "__main__":
    import sys
    outdir = sys.argv[1] if len(sys.argv) > 1 else "out"
    import os; os.makedirs(outdir, exist_ok=True)
    with open(f"{outdir}/asset_schema_postgresql.sql", "w", encoding="utf-8") as f:
        f.write(gen_pg())
    with open(f"{outdir}/asset_schema_erdcloud_mysql.sql", "w", encoding="utf-8") as f:
        f.write(gen_mysql())
    print("tables:", len(TABLES),
          "| columns:", sum(len(t["cols"]) for t in TABLES),
          "| foreign keys:", sum(len(t["fks"]) for t in TABLES))
