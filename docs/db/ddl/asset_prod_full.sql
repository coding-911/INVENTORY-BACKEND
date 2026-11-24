-- ============================================================
-- 자산관리 시스템 PostgreSQL DDL — ③ 운영 최종본 (v1 + v2)
-- 생성: 2026-11-24 / 기준: 노션 '테이블 정의서', '불변 조건 목록'
-- 대상: PostgreSQL 18 이상 (uuidv7(), UNIQUE NULLS NOT DISTINCT 사용)
-- 운영 DB를 처음 만들 때 이 파일 하나만 실행한다.
-- v1 → v2를 순서대로 적용한 DB와 스키마가 같다 (생성 시 자동 비교).
-- Flyway 도입 시 이 파일을 운영 기준선(baseline)으로 삼는다.
-- ============================================================

BEGIN;

CREATE SCHEMA IF NOT EXISTS auth;
CREATE SCHEMA IF NOT EXISTS product;
CREATE SCHEMA IF NOT EXISTS warehouse;
CREATE SCHEMA IF NOT EXISTS partner;
CREATE SCHEMA IF NOT EXISTS inventory;
CREATE SCHEMA IF NOT EXISTS equipment;
CREATE SCHEMA IF NOT EXISTS project;
CREATE SCHEMA IF NOT EXISTS allocation;
CREATE SCHEMA IF NOT EXISTS delivery;
CREATE SCHEMA IF NOT EXISTS loan;
CREATE SCHEMA IF NOT EXISTS trash;
CREATE SCHEMA IF NOT EXISTS cost;
CREATE SCHEMA IF NOT EXISTS importing;
CREATE SCHEMA IF NOT EXISTS common;
CREATE SCHEMA IF NOT EXISTS admin;

CREATE TABLE auth.users (
    id uuid NOT NULL DEFAULT uuidv7(),
    login_id varchar(50) NOT NULL,
    name varchar(100) NOT NULL,
    email varchar(200),
    password_hash varchar(200) NOT NULL,
    is_active boolean NOT NULL DEFAULT true,
    last_login_at timestamptz,
    tokens_valid_after timestamptz,
    must_change_password boolean NOT NULL DEFAULT false,
    created_at timestamptz NOT NULL DEFAULT now(),
    created_by uuid NOT NULL,
    updated_at timestamptz,
    updated_by uuid,
    version integer NOT NULL DEFAULT 0,
    deleted_at timestamptz,
    deleted_by uuid,
    CONSTRAINT pk_users PRIMARY KEY (id)
);

CREATE TABLE auth.roles (
    id uuid NOT NULL DEFAULT uuidv7(),
    code varchar(30) NOT NULL,
    name varchar(100) NOT NULL,
    CONSTRAINT pk_roles PRIMARY KEY (id),
    CONSTRAINT uq_roles_code UNIQUE (code)
);

CREATE TABLE auth.user_roles (
    user_id uuid NOT NULL,
    role_id uuid NOT NULL,
    CONSTRAINT pk_user_roles PRIMARY KEY (user_id, role_id)
);

CREATE TABLE auth.user_permissions (
    user_id uuid NOT NULL,
    permission varchar(30) NOT NULL,
    CONSTRAINT pk_user_permissions PRIMARY KEY (user_id, permission),
    CONSTRAINT ck_user_permissions_1 CHECK (permission IN ('COST_VIEW', 'COST_EDIT'))
);

CREATE TABLE auth.oauth2_authorization (
    id varchar(100) NOT NULL,
    registered_client_id varchar(100) NOT NULL,
    principal_name varchar(200) NOT NULL,
    authorization_grant_type varchar(100) NOT NULL,
    authorized_scopes varchar(1000),
    attributes text,
    state varchar(500),
    authorization_code_value text,
    authorization_code_issued_at timestamp,
    authorization_code_expires_at timestamp,
    authorization_code_metadata text,
    access_token_value text,
    access_token_issued_at timestamp,
    access_token_expires_at timestamp,
    access_token_metadata text,
    access_token_type varchar(100),
    access_token_scopes varchar(1000),
    oidc_id_token_value text,
    oidc_id_token_issued_at timestamp,
    oidc_id_token_expires_at timestamp,
    oidc_id_token_metadata text,
    refresh_token_value text,
    refresh_token_issued_at timestamp,
    refresh_token_expires_at timestamp,
    refresh_token_metadata text,
    user_code_value text,
    user_code_issued_at timestamp,
    user_code_expires_at timestamp,
    user_code_metadata text,
    device_code_value text,
    device_code_issued_at timestamp,
    device_code_expires_at timestamp,
    device_code_metadata text,
    CONSTRAINT pk_oauth2_authorization PRIMARY KEY (id)
);

CREATE TABLE product.product_categories (
    id uuid NOT NULL DEFAULT uuidv7(),
    code varchar(30) NOT NULL,
    name varchar(100) NOT NULL,
    sort_order integer NOT NULL DEFAULT 0,
    is_active boolean NOT NULL DEFAULT true,
    deleted_at timestamptz,
    deleted_by uuid,
    CONSTRAINT pk_product_categories PRIMARY KEY (id)
);

CREATE TABLE product.products (
    id uuid NOT NULL DEFAULT uuidv7(),
    item_code varchar(50) NOT NULL,
    product_name varchar(200) NOT NULL,
    model_name varchar(100),
    category_id uuid NOT NULL,
    manufacturer varchar(100),
    component_role varchar(100),
    specification text,
    unit varchar(20) NOT NULL DEFAULT 'EA',
    serial_managed boolean NOT NULL DEFAULT false,
    is_active boolean NOT NULL DEFAULT true,
    note text,
    created_at timestamptz NOT NULL DEFAULT now(),
    created_by uuid NOT NULL,
    updated_at timestamptz,
    updated_by uuid,
    version integer NOT NULL DEFAULT 0,
    deleted_at timestamptz,
    deleted_by uuid,
    CONSTRAINT pk_products PRIMARY KEY (id)
);

CREATE TABLE product.product_changes (
    id uuid NOT NULL DEFAULT uuidv7(),
    product_id uuid NOT NULL,
    field_name varchar(50) NOT NULL,
    old_value text,
    new_value text,
    reason text,
    changed_by uuid NOT NULL,
    changed_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT pk_product_changes PRIMARY KEY (id)
);

CREATE TABLE product.bundles (
    id uuid NOT NULL DEFAULT uuidv7(),
    bundle_code varchar(30) NOT NULL,
    bundle_name varchar(200) NOT NULL,
    is_active boolean NOT NULL DEFAULT true,
    note text,
    created_at timestamptz NOT NULL DEFAULT now(),
    created_by uuid NOT NULL,
    updated_at timestamptz,
    updated_by uuid,
    version integer NOT NULL DEFAULT 0,
    deleted_at timestamptz,
    deleted_by uuid,
    CONSTRAINT pk_bundles PRIMARY KEY (id)
);

CREATE TABLE product.bundle_components (
    id uuid NOT NULL DEFAULT uuidv7(),
    bundle_id uuid NOT NULL,
    product_id uuid NOT NULL,
    quantity_per_set integer NOT NULL,
    CONSTRAINT pk_bundle_components PRIMARY KEY (id),
    CONSTRAINT uq_bundle_components_bundle_id_product_id UNIQUE (bundle_id, product_id),
    CONSTRAINT ck_bundle_components_1 CHECK (quantity_per_set > 0)
);

CREATE TABLE warehouse.warehouses (
    id uuid NOT NULL DEFAULT uuidv7(),
    warehouse_code varchar(30) NOT NULL,
    warehouse_name varchar(100) NOT NULL,
    address varchar(300),
    is_active boolean NOT NULL DEFAULT true,
    note text,
    created_at timestamptz NOT NULL DEFAULT now(),
    created_by uuid NOT NULL,
    updated_at timestamptz,
    updated_by uuid,
    version integer NOT NULL DEFAULT 0,
    deleted_at timestamptz,
    deleted_by uuid,
    CONSTRAINT pk_warehouses PRIMARY KEY (id)
);

CREATE TABLE warehouse.locations (
    id uuid NOT NULL DEFAULT uuidv7(),
    location_code varchar(30) NOT NULL,
    location_name varchar(100) NOT NULL,
    location_type varchar(20) NOT NULL DEFAULT 'INTERNAL',
    warehouse_id uuid,
    partner_id uuid,
    zone varchar(30),
    rack varchar(30),
    shelf varchar(30),
    is_active boolean NOT NULL DEFAULT true,
    note text,
    created_at timestamptz NOT NULL DEFAULT now(),
    created_by uuid NOT NULL,
    updated_at timestamptz,
    updated_by uuid,
    version integer NOT NULL DEFAULT 0,
    deleted_at timestamptz,
    deleted_by uuid,
    CONSTRAINT pk_locations PRIMARY KEY (id),
    CONSTRAINT ck_locations_1 CHECK (location_type IN ('INTERNAL', 'REPAIR', 'LOAN_OUT', 'CUSTOMER_SITE')),
    CONSTRAINT ck_locations_2 CHECK ((location_type = 'INTERNAL' AND warehouse_id IS NOT NULL AND partner_id IS NULL) OR (location_type <> 'INTERNAL' AND partner_id IS NOT NULL))
);

CREATE TABLE partner.partners (
    id uuid NOT NULL DEFAULT uuidv7(),
    partner_name varchar(200) NOT NULL,
    business_reg_no varchar(20),
    address varchar(300),
    phone varchar(50),
    is_active boolean NOT NULL DEFAULT true,
    note text,
    created_at timestamptz NOT NULL DEFAULT now(),
    created_by uuid NOT NULL,
    updated_at timestamptz,
    updated_by uuid,
    version integer NOT NULL DEFAULT 0,
    deleted_at timestamptz,
    deleted_by uuid,
    CONSTRAINT pk_partners PRIMARY KEY (id)
);

CREATE TABLE partner.partner_roles (
    partner_id uuid NOT NULL,
    role varchar(20) NOT NULL,
    CONSTRAINT pk_partner_roles PRIMARY KEY (partner_id, role),
    CONSTRAINT ck_partner_roles_1 CHECK (role IN ('CUSTOMER', 'SUPPLIER'))
);

CREATE TABLE partner.contacts (
    id uuid NOT NULL DEFAULT uuidv7(),
    partner_id uuid NOT NULL,
    name varchar(100) NOT NULL,
    department varchar(100),
    position varchar(100),
    phone varchar(50),
    email varchar(200),
    is_primary boolean NOT NULL DEFAULT false,
    created_at timestamptz NOT NULL DEFAULT now(),
    created_by uuid NOT NULL,
    updated_at timestamptz,
    updated_by uuid,
    version integer NOT NULL DEFAULT 0,
    deleted_at timestamptz,
    deleted_by uuid,
    CONSTRAINT pk_contacts PRIMARY KEY (id)
);

CREATE TABLE inventory.stock_transactions (
    id uuid NOT NULL DEFAULT uuidv7(),
    transaction_no varchar(30) NOT NULL,
    transaction_type varchar(30) NOT NULL,
    business_date date NOT NULL,
    status varchar(10) NOT NULL DEFAULT 'DRAFT',
    request_id varchar(64) NOT NULL,
    related_transaction_id uuid,
    source_type varchar(30),
    source_id uuid,
    counterparty_partner_id uuid,
    reason_code varchar(30),
    reason text,
    reference_no varchar(100),
    approved_by uuid,
    approved_at timestamptz,
    note text,
    created_at timestamptz NOT NULL DEFAULT now(),
    created_by uuid NOT NULL,
    posted_at timestamptz,
    posted_by uuid,
    CONSTRAINT pk_stock_transactions PRIMARY KEY (id),
    CONSTRAINT uq_stock_transactions_transaction_no UNIQUE (transaction_no),
    CONSTRAINT uq_stock_transactions_request_id UNIQUE (request_id),
    CONSTRAINT ck_stock_transactions_1 CHECK (transaction_type IN ('OPENING', 'RECEIPT', 'UNPLANNED_RECEIPT', 'ISSUE', 'TRANSFER', 'ADJUSTMENT', 'CUSTOMER_RETURN', 'INSPECTION_RESULT', 'SUPPLIER_RETURN', 'REPAIR_OUT', 'REPAIR_IN', 'EXCHANGE', 'DISPOSAL', 'LOAN_IN_RECEIPT', 'LOAN_IN_REPAY', 'LOAN_IN_RETURN', 'TEMP_INSTALL', 'LOAN_OUT_ISSUE', 'LOAN_OUT_RETURN', 'LOAN_OUT_SETTLE', 'OWNERSHIP_TRANSFER', 'REVERSAL', 'CORRECTION')),
    CONSTRAINT ck_stock_transactions_2 CHECK (status IN ('DRAFT', 'POSTED'))
);

CREATE TABLE inventory.ledger_entries (
    id uuid NOT NULL DEFAULT uuidv7(),
    transaction_id uuid NOT NULL,
    line_no integer NOT NULL,
    product_id uuid NOT NULL,
    location_id uuid NOT NULL,
    stock_condition varchar(20) NOT NULL,
    owner_type varchar(20) NOT NULL DEFAULT 'OWN',
    owner_partner_id uuid,
    quantity_delta integer NOT NULL,
    business_date date NOT NULL,
    equipment_id uuid,
    pair_id uuid,
    reversal_of_entry_id uuid,
    trade_line_id uuid,
    lot_no varchar(50),
    item_code_snapshot varchar(50) NOT NULL,
    product_name_snapshot varchar(200) NOT NULL,
    note text,
    created_at timestamptz NOT NULL DEFAULT now(),
    created_by uuid NOT NULL,
    CONSTRAINT pk_ledger_entries PRIMARY KEY (id),
    CONSTRAINT uq_ledger_entries_transaction_id_line_no UNIQUE (transaction_id, line_no),
    CONSTRAINT uq_ledger_entries_reversal_of_entry_id UNIQUE (reversal_of_entry_id),
    CONSTRAINT ck_ledger_entries_1 CHECK (stock_condition IN ('AVAILABLE', 'INSPECTION', 'DEFECTIVE', 'IN_REPAIR')),
    CONSTRAINT ck_ledger_entries_2 CHECK (owner_type IN ('OWN', 'THIRD_PARTY')),
    CONSTRAINT ck_ledger_entries_3 CHECK ((owner_type = 'OWN' AND owner_partner_id IS NULL) OR (owner_type = 'THIRD_PARTY' AND owner_partner_id IS NOT NULL)),
    CONSTRAINT ck_ledger_entries_4 CHECK (quantity_delta <> 0)
);

CREATE TABLE inventory.stock_balances (
    id uuid NOT NULL DEFAULT uuidv7(),
    product_id uuid NOT NULL,
    location_id uuid NOT NULL,
    stock_condition varchar(20) NOT NULL,
    owner_type varchar(20) NOT NULL DEFAULT 'OWN',
    owner_partner_id uuid,
    quantity integer NOT NULL DEFAULT 0,
    updated_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT pk_stock_balances PRIMARY KEY (id),
    CONSTRAINT ck_stock_balances_1 CHECK (stock_condition IN ('AVAILABLE', 'INSPECTION', 'DEFECTIVE', 'IN_REPAIR')),
    CONSTRAINT ck_stock_balances_2 CHECK (owner_type IN ('OWN', 'THIRD_PARTY')),
    CONSTRAINT ck_stock_balances_3 CHECK ((owner_type = 'OWN' AND owner_partner_id IS NULL) OR (owner_type = 'THIRD_PARTY' AND owner_partner_id IS NOT NULL)),
    CONSTRAINT ck_stock_balances_4 CHECK (quantity >= 0)
);

CREATE TABLE inventory.period_closings (
    id uuid NOT NULL DEFAULT uuidv7(),
    period char(7) NOT NULL,
    status varchar(10) NOT NULL DEFAULT 'OPEN',
    closed_at timestamptz,
    closed_by uuid,
    snapshot_version integer NOT NULL DEFAULT 0,
    CONSTRAINT pk_period_closings PRIMARY KEY (id),
    CONSTRAINT uq_period_closings_period UNIQUE (period),
    CONSTRAINT ck_period_closings_1 CHECK (status IN ('OPEN', 'CLOSED'))
);

CREATE TABLE inventory.period_closing_events (
    id uuid NOT NULL DEFAULT uuidv7(),
    period char(7) NOT NULL,
    action varchar(10) NOT NULL,
    reason text,
    acted_by uuid NOT NULL,
    acted_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT pk_period_closing_events PRIMARY KEY (id),
    CONSTRAINT ck_period_closing_events_1 CHECK (action IN ('CLOSE', 'REOPEN'))
);

CREATE TABLE inventory.monthly_stock_snapshots (
    id uuid NOT NULL DEFAULT uuidv7(),
    period char(7) NOT NULL,
    snapshot_version integer NOT NULL,
    product_id uuid NOT NULL,
    location_id uuid NOT NULL,
    stock_condition varchar(20) NOT NULL,
    owner_type varchar(20) NOT NULL DEFAULT 'OWN',
    owner_partner_id uuid,
    quantity integer NOT NULL,
    CONSTRAINT pk_monthly_stock_snapshots PRIMARY KEY (id)
);

CREATE TABLE inventory.stock_counts (
    id uuid NOT NULL DEFAULT uuidv7(),
    count_no varchar(30) NOT NULL,
    scope_type varchar(20) NOT NULL,
    base_date date NOT NULL,
    assignee_id uuid NOT NULL,
    status varchar(20) NOT NULL DEFAULT 'PREPARED',
    started_at timestamptz,
    approved_by uuid,
    approved_at timestamptz,
    adjustment_transaction_id uuid,
    note text,
    created_at timestamptz NOT NULL DEFAULT now(),
    created_by uuid NOT NULL,
    updated_at timestamptz,
    updated_by uuid,
    version integer NOT NULL DEFAULT 0,
    CONSTRAINT pk_stock_counts PRIMARY KEY (id),
    CONSTRAINT uq_stock_counts_count_no UNIQUE (count_no),
    CONSTRAINT ck_stock_counts_1 CHECK (scope_type IN ('LOCATION', 'PRODUCT')),
    CONSTRAINT ck_stock_counts_2 CHECK (status IN ('PREPARED', 'IN_PROGRESS', 'REVIEW', 'APPROVED', 'CANCELLED'))
);

CREATE TABLE inventory.stock_count_scopes (
    id uuid NOT NULL DEFAULT uuidv7(),
    count_id uuid NOT NULL,
    location_id uuid,
    product_id uuid,
    CONSTRAINT pk_stock_count_scopes PRIMARY KEY (id),
    CONSTRAINT ck_stock_count_scopes_1 CHECK (location_id IS NOT NULL OR product_id IS NOT NULL)
);

CREATE TABLE inventory.stock_count_lines (
    id uuid NOT NULL DEFAULT uuidv7(),
    count_id uuid NOT NULL,
    product_id uuid NOT NULL,
    location_id uuid NOT NULL,
    stock_condition varchar(20) NOT NULL,
    owner_type varchar(20) NOT NULL DEFAULT 'OWN',
    owner_partner_id uuid,
    book_quantity integer NOT NULL,
    counted_quantity integer,
    recounted boolean NOT NULL DEFAULT false,
    note text,
    CONSTRAINT pk_stock_count_lines PRIMARY KEY (id),
    CONSTRAINT ck_stock_count_lines_1 CHECK (stock_condition IN ('AVAILABLE', 'INSPECTION', 'DEFECTIVE', 'IN_REPAIR')),
    CONSTRAINT ck_stock_count_lines_2 CHECK (owner_type IN ('OWN', 'THIRD_PARTY')),
    CONSTRAINT ck_stock_count_lines_3 CHECK ((owner_type = 'OWN' AND owner_partner_id IS NULL) OR (owner_type = 'THIRD_PARTY' AND owner_partner_id IS NOT NULL))
);

CREATE TABLE inventory.stock_count_serials (
    id uuid NOT NULL DEFAULT uuidv7(),
    count_id uuid NOT NULL,
    line_id uuid NOT NULL,
    serial_no varchar(100) NOT NULL,
    equipment_id uuid,
    result varchar(20) NOT NULL,
    CONSTRAINT pk_stock_count_serials PRIMARY KEY (id),
    CONSTRAINT ck_stock_count_serials_1 CHECK (result IN ('MATCHED', 'MISSING', 'UNEXPECTED'))
);

CREATE TABLE equipment.equipment (
    id uuid NOT NULL DEFAULT uuidv7(),
    product_id uuid NOT NULL,
    serial_no varchar(100),
    serial_status varchar(20) NOT NULL DEFAULT 'CONFIRMED',
    status varchar(30) NOT NULL,
    current_location_id uuid,
    owner_type varchar(20) NOT NULL DEFAULT 'OWN',
    owner_partner_id uuid,
    project_id uuid,
    delivered_partner_id uuid,
    replaced_by_equipment_id uuid,
    origin_type varchar(30) NOT NULL DEFAULT 'LEDGER',
    last_event_date date NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    created_by uuid NOT NULL,
    updated_at timestamptz,
    updated_by uuid,
    version integer NOT NULL DEFAULT 0,
    CONSTRAINT pk_equipment PRIMARY KEY (id),
    CONSTRAINT ck_equipment_1 CHECK (serial_status IN ('CONFIRMED', 'UNKNOWN')),
    CONSTRAINT ck_equipment_2 CHECK (status IN ('IN_STOCK', 'INSPECTION', 'DEFECTIVE', 'IN_REPAIR', 'ISSUED', 'DELIVERED', 'TEMP_INSTALLED', 'LOANED_OUT', 'LOST', 'REPLACED', 'DISPOSED', 'RETURNED_TO_SUPPLIER', 'TRANSFERRED_OUT', 'RECEIPT_CANCELLED')),
    CONSTRAINT ck_equipment_3 CHECK (owner_type IN ('OWN', 'THIRD_PARTY')),
    CONSTRAINT ck_equipment_4 CHECK ((owner_type = 'OWN' AND owner_partner_id IS NULL) OR (owner_type = 'THIRD_PARTY' AND owner_partner_id IS NOT NULL)),
    CONSTRAINT ck_equipment_5 CHECK (serial_status = 'UNKNOWN' OR serial_no IS NOT NULL),
    CONSTRAINT ck_equipment_6 CHECK (origin_type IN ('LEDGER', 'PRE_CUTOVER_DELIVERY'))
);

CREATE TABLE equipment.equipment_events (
    id uuid NOT NULL DEFAULT uuidv7(),
    equipment_id uuid NOT NULL,
    event_type varchar(30) NOT NULL,
    business_date date NOT NULL,
    from_status varchar(30),
    to_status varchar(30),
    from_location_id uuid,
    to_location_id uuid,
    old_value text,
    new_value text,
    ledger_entry_id uuid,
    source_type varchar(30),
    source_id uuid,
    note text,
    created_at timestamptz NOT NULL DEFAULT now(),
    created_by uuid NOT NULL,
    CONSTRAINT pk_equipment_events PRIMARY KEY (id)
);

CREATE TABLE equipment.warranties (
    id uuid NOT NULL DEFAULT uuidv7(),
    equipment_id uuid NOT NULL,
    status varchar(20) NOT NULL DEFAULT 'UNKNOWN',
    start_date date,
    end_date date,
    basis varchar(20),
    inherited_from_equipment_id uuid,
    note text,
    created_at timestamptz NOT NULL DEFAULT now(),
    created_by uuid NOT NULL,
    updated_at timestamptz,
    updated_by uuid,
    version integer NOT NULL DEFAULT 0,
    CONSTRAINT pk_warranties PRIMARY KEY (id),
    CONSTRAINT uq_warranties_equipment_id UNIQUE (equipment_id),
    CONSTRAINT ck_warranties_1 CHECK (status IN ('CONFIRMED', 'UNKNOWN')),
    CONSTRAINT ck_warranties_2 CHECK (end_date IS NULL OR start_date IS NULL OR end_date >= start_date),
    CONSTRAINT ck_warranties_3 CHECK (basis IS NULL OR basis IN ('DELIVERY', 'MANUFACTURER', 'PURCHASE', 'MANUAL'))
);

CREATE TABLE equipment.warranty_changes (
    id uuid NOT NULL DEFAULT uuidv7(),
    warranty_id uuid NOT NULL,
    old_start_date date,
    old_end_date date,
    new_start_date date,
    new_end_date date,
    reason text,
    changed_by uuid NOT NULL,
    changed_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT pk_warranty_changes PRIMARY KEY (id)
);

CREATE TABLE project.projects (
    id uuid NOT NULL DEFAULT uuidv7(),
    project_code varchar(30) NOT NULL,
    project_name varchar(200) NOT NULL,
    customer_partner_id uuid,
    status varchar(20) NOT NULL DEFAULT 'ACTIVE',
    note text,
    created_at timestamptz NOT NULL DEFAULT now(),
    created_by uuid NOT NULL,
    updated_at timestamptz,
    updated_by uuid,
    version integer NOT NULL DEFAULT 0,
    deleted_at timestamptz,
    deleted_by uuid,
    CONSTRAINT pk_projects PRIMARY KEY (id),
    CONSTRAINT uq_projects_project_code UNIQUE (project_code),
    CONSTRAINT ck_projects_1 CHECK (status IN ('ACTIVE', 'COMPLETED', 'CANCELLED'))
);

CREATE TABLE project.trade_documents (
    id uuid NOT NULL DEFAULT uuidv7(),
    project_id uuid NOT NULL,
    trade_type varchar(20) NOT NULL,
    partner_id uuid NOT NULL,
    document_no varchar(50),
    document_date date NOT NULL,
    status varchar(20) NOT NULL DEFAULT 'DRAFT',
    copied_from_document_id uuid,
    note text,
    created_at timestamptz NOT NULL DEFAULT now(),
    created_by uuid NOT NULL,
    updated_at timestamptz,
    updated_by uuid,
    version integer NOT NULL DEFAULT 0,
    deleted_at timestamptz,
    deleted_by uuid,
    CONSTRAINT pk_trade_documents PRIMARY KEY (id),
    CONSTRAINT ck_trade_documents_1 CHECK (trade_type IN ('PURCHASE', 'SALES', 'PRE_ORDER')),
    CONSTRAINT ck_trade_documents_2 CHECK (status IN ('DRAFT', 'CONFIRMED', 'COMPLETED', 'CANCELLED'))
);

CREATE TABLE project.trade_lines (
    id uuid NOT NULL DEFAULT uuidv7(),
    document_id uuid NOT NULL,
    line_no integer NOT NULL,
    product_id uuid NOT NULL,
    quantity integer NOT NULL,
    opening_fulfilled_quantity integer NOT NULL DEFAULT 0,
    fulfilled_quantity integer NOT NULL DEFAULT 0,
    closed_quantity integer NOT NULL DEFAULT 0,
    closed_reason text,
    closed_by uuid,
    closed_at timestamptz,
    route varchar(20) NOT NULL DEFAULT 'WAREHOUSE',
    note text,
    created_at timestamptz NOT NULL DEFAULT now(),
    created_by uuid NOT NULL,
    updated_at timestamptz,
    updated_by uuid,
    version integer NOT NULL DEFAULT 0,
    CONSTRAINT pk_trade_lines PRIMARY KEY (id),
    CONSTRAINT uq_trade_lines_document_id_line_no UNIQUE (document_id, line_no),
    CONSTRAINT ck_trade_lines_1 CHECK (quantity > 0),
    CONSTRAINT ck_trade_lines_2 CHECK (fulfilled_quantity >= 0),
    CONSTRAINT ck_trade_lines_3 CHECK (closed_quantity >= 0),
    CONSTRAINT ck_trade_lines_4 CHECK (opening_fulfilled_quantity + fulfilled_quantity + closed_quantity <= quantity),
    CONSTRAINT ck_trade_lines_5 CHECK (route IN ('WAREHOUSE', 'DIRECT')),
    CONSTRAINT ck_trade_lines_6 CHECK (opening_fulfilled_quantity >= 0)
);

CREATE TABLE project.trade_document_changes (
    id uuid NOT NULL DEFAULT uuidv7(),
    document_id uuid NOT NULL,
    line_id uuid,
    field_name varchar(50) NOT NULL,
    old_value text,
    new_value text,
    reason text,
    changed_by uuid NOT NULL,
    changed_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT pk_trade_document_changes PRIMARY KEY (id)
);

CREATE TABLE allocation.allocations (
    id uuid NOT NULL DEFAULT uuidv7(),
    product_id uuid NOT NULL,
    quantity integer NOT NULL,
    consumed_quantity integer NOT NULL DEFAULT 0,
    target_type varchar(20) NOT NULL,
    project_id uuid,
    loan_document_id uuid,
    source_type varchar(20) NOT NULL,
    source_trade_line_id uuid,
    owner_type varchar(20),
    owner_partner_id uuid,
    equipment_id uuid,
    status varchar(20) NOT NULL DEFAULT 'ACTIVE',
    note text,
    created_at timestamptz NOT NULL DEFAULT now(),
    created_by uuid NOT NULL,
    updated_at timestamptz,
    updated_by uuid,
    version integer NOT NULL DEFAULT 0,
    CONSTRAINT pk_allocations PRIMARY KEY (id),
    CONSTRAINT ck_allocations_1 CHECK (quantity > 0),
    CONSTRAINT ck_allocations_2 CHECK (consumed_quantity >= 0 AND consumed_quantity <= quantity),
    CONSTRAINT ck_allocations_3 CHECK (target_type IN ('PROJECT', 'LOAN_REPAY')),
    CONSTRAINT ck_allocations_4 CHECK ((target_type = 'PROJECT' AND project_id IS NOT NULL) OR (target_type = 'LOAN_REPAY' AND loan_document_id IS NOT NULL)),
    CONSTRAINT ck_allocations_5 CHECK (source_type IN ('STOCK', 'RECEIVED', 'PLANNED')),
    CONSTRAINT ck_allocations_6 CHECK (source_type = 'STOCK' OR source_trade_line_id IS NOT NULL),
    CONSTRAINT ck_allocations_7 CHECK (owner_type IS NULL OR owner_type IN ('OWN', 'THIRD_PARTY')),
    CONSTRAINT ck_allocations_8 CHECK (status IN ('ACTIVE', 'RELEASED', 'CONSUMED'))
);

CREATE TABLE allocation.allocation_events (
    id uuid NOT NULL DEFAULT uuidv7(),
    allocation_id uuid NOT NULL,
    action varchar(20) NOT NULL,
    quantity integer NOT NULL,
    reason text,
    acted_by uuid NOT NULL,
    acted_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT pk_allocation_events PRIMARY KEY (id),
    CONSTRAINT ck_allocation_events_1 CHECK (action IN ('ALLOCATE', 'CHANGE', 'RELEASE', 'CONSUME', 'CONVERT'))
);

CREATE TABLE delivery.deliveries (
    id uuid NOT NULL DEFAULT uuidv7(),
    delivery_no varchar(30) NOT NULL,
    project_id uuid NOT NULL,
    sales_document_id uuid,
    customer_partner_id uuid NOT NULL,
    delivery_date date NOT NULL,
    place varchar(300),
    route varchar(20) NOT NULL DEFAULT 'WAREHOUSE',
    bundle_id uuid,
    bundle_set_quantity integer,
    status varchar(20) NOT NULL DEFAULT 'DRAFT',
    transaction_id uuid,
    note text,
    created_at timestamptz NOT NULL DEFAULT now(),
    created_by uuid NOT NULL,
    updated_at timestamptz,
    updated_by uuid,
    version integer NOT NULL DEFAULT 0,
    CONSTRAINT pk_deliveries PRIMARY KEY (id),
    CONSTRAINT uq_deliveries_delivery_no UNIQUE (delivery_no),
    CONSTRAINT ck_deliveries_1 CHECK (route IN ('WAREHOUSE', 'DIRECT')),
    CONSTRAINT ck_deliveries_2 CHECK (status IN ('DRAFT', 'POSTED', 'CANCELLED')),
    CONSTRAINT ck_deliveries_3 CHECK ((bundle_id IS NULL AND bundle_set_quantity IS NULL) OR (bundle_id IS NOT NULL AND bundle_set_quantity > 0))
);

CREATE TABLE delivery.delivery_lines (
    id uuid NOT NULL DEFAULT uuidv7(),
    delivery_id uuid NOT NULL,
    line_no integer NOT NULL,
    product_id uuid NOT NULL,
    quantity integer NOT NULL,
    sales_line_id uuid,
    purchase_line_id uuid,
    loan_line_id uuid,
    equipment_id uuid,
    returned_quantity integer NOT NULL DEFAULT 0,
    note text,
    CONSTRAINT pk_delivery_lines PRIMARY KEY (id),
    CONSTRAINT uq_delivery_lines_delivery_id_line_no UNIQUE (delivery_id, line_no),
    CONSTRAINT ck_delivery_lines_1 CHECK (quantity > 0),
    CONSTRAINT ck_delivery_lines_2 CHECK (returned_quantity >= 0 AND returned_quantity <= quantity)
);

CREATE TABLE delivery.delivery_returns (
    id uuid NOT NULL DEFAULT uuidv7(),
    delivery_line_id uuid,
    equipment_id uuid,
    quantity integer NOT NULL,
    return_date date NOT NULL,
    transaction_id uuid,
    reason text,
    created_at timestamptz NOT NULL DEFAULT now(),
    created_by uuid NOT NULL,
    updated_at timestamptz,
    updated_by uuid,
    version integer NOT NULL DEFAULT 0,
    CONSTRAINT pk_delivery_returns PRIMARY KEY (id),
    CONSTRAINT ck_delivery_returns_1 CHECK (quantity > 0),
    CONSTRAINT ck_delivery_returns_2 CHECK (delivery_line_id IS NOT NULL OR (equipment_id IS NOT NULL AND quantity = 1))
);

CREATE TABLE loan.loan_documents (
    id uuid NOT NULL DEFAULT uuidv7(),
    loan_no varchar(30) NOT NULL,
    direction varchar(10) NOT NULL,
    partner_id uuid NOT NULL,
    project_id uuid,
    settlement_method varchar(20) NOT NULL,
    due_date date,
    status varchar(20) NOT NULL DEFAULT 'OPEN',
    converted_trade_document_id uuid,
    approved_by uuid,
    approved_at timestamptz,
    note text,
    created_at timestamptz NOT NULL DEFAULT now(),
    created_by uuid NOT NULL,
    updated_at timestamptz,
    updated_by uuid,
    version integer NOT NULL DEFAULT 0,
    deleted_at timestamptz,
    deleted_by uuid,
    CONSTRAINT pk_loan_documents PRIMARY KEY (id),
    CONSTRAINT uq_loan_documents_loan_no UNIQUE (loan_no),
    CONSTRAINT ck_loan_documents_1 CHECK (direction IN ('IN', 'OUT')),
    CONSTRAINT ck_loan_documents_2 CHECK (settlement_method IN ('IN_KIND', 'CONVERT', 'RETURN_ORIGINAL')),
    CONSTRAINT ck_loan_documents_3 CHECK (status IN ('OPEN', 'SETTLED', 'CANCELLED'))
);

CREATE TABLE loan.loan_lines (
    id uuid NOT NULL DEFAULT uuidv7(),
    loan_id uuid NOT NULL,
    line_no integer NOT NULL,
    product_id uuid NOT NULL,
    quantity integer NOT NULL,
    moved_quantity integer NOT NULL DEFAULT 0,
    settled_quantity integer NOT NULL DEFAULT 0,
    equipment_id uuid,
    note text,
    CONSTRAINT pk_loan_lines PRIMARY KEY (id),
    CONSTRAINT uq_loan_lines_loan_id_line_no UNIQUE (loan_id, line_no),
    CONSTRAINT ck_loan_lines_1 CHECK (quantity > 0),
    CONSTRAINT ck_loan_lines_2 CHECK (settled_quantity >= 0 AND settled_quantity <= quantity),
    CONSTRAINT ck_loan_lines_3 CHECK (moved_quantity >= 0 AND moved_quantity <= quantity)
);

CREATE TABLE loan.loan_settlements (
    id uuid NOT NULL DEFAULT uuidv7(),
    loan_line_id uuid NOT NULL,
    settled_date date NOT NULL,
    method varchar(20) NOT NULL,
    quantity integer NOT NULL,
    settled_product_id uuid NOT NULL,
    equipment_id uuid,
    status varchar(20) NOT NULL DEFAULT 'POSTED',
    transaction_id uuid,
    trade_document_id uuid,
    note text,
    created_at timestamptz NOT NULL DEFAULT now(),
    created_by uuid NOT NULL,
    updated_at timestamptz,
    updated_by uuid,
    version integer NOT NULL DEFAULT 0,
    CONSTRAINT pk_loan_settlements PRIMARY KEY (id),
    CONSTRAINT ck_loan_settlements_1 CHECK (quantity > 0),
    CONSTRAINT ck_loan_settlements_2 CHECK (method IN ('IN_KIND', 'CONVERT', 'RETURN_ORIGINAL')),
    CONSTRAINT ck_loan_settlements_3 CHECK (status IN ('PENDING_APPROVAL', 'POSTED', 'REJECTED', 'CANCELLED')),
    CONSTRAINT ck_loan_settlements_4 CHECK (method <> 'CONVERT' OR trade_document_id IS NOT NULL),
    CONSTRAINT ck_loan_settlements_5 CHECK (equipment_id IS NULL OR quantity = 1)
);

CREATE TABLE loan.loan_document_changes (
    id uuid NOT NULL DEFAULT uuidv7(),
    loan_id uuid NOT NULL,
    line_id uuid,
    field_name varchar(50) NOT NULL,
    old_value text,
    new_value text,
    reason text,
    changed_by uuid NOT NULL,
    changed_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT pk_loan_document_changes PRIMARY KEY (id)
);

CREATE TABLE trash.trash_events (
    id uuid NOT NULL DEFAULT uuidv7(),
    entity_type varchar(50) NOT NULL,
    entity_id uuid NOT NULL,
    action varchar(10) NOT NULL,
    reason text,
    acted_by uuid NOT NULL,
    acted_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT pk_trash_events PRIMARY KEY (id),
    CONSTRAINT ck_trash_events_1 CHECK (action IN ('DELETE', 'RESTORE'))
);

CREATE TABLE cost.currencies (
    code char(3) NOT NULL,
    name varchar(50) NOT NULL,
    minor_unit smallint NOT NULL,
    is_active boolean NOT NULL DEFAULT false,
    CONSTRAINT pk_currencies PRIMARY KEY (code),
    CONSTRAINT ck_currencies_1 CHECK (minor_unit BETWEEN 0 AND 4)
);

CREATE TABLE cost.line_prices (
    trade_line_id uuid NOT NULL,
    unit_price numeric(19,4) NOT NULL,
    currency char(3) NOT NULL DEFAULT 'KRW',
    exchange_rate numeric(18,6) NOT NULL DEFAULT 1,
    exchange_rate_date date,
    unit_price_krw numeric(19,4) NOT NULL,
    tax_type varchar(20),
    attribution_basis varchar(20) NOT NULL DEFAULT 'DOCUMENT_DATE',
    attribution_date date,
    created_at timestamptz NOT NULL DEFAULT now(),
    created_by uuid NOT NULL,
    updated_at timestamptz,
    updated_by uuid,
    version integer NOT NULL DEFAULT 0,
    CONSTRAINT pk_line_prices PRIMARY KEY (trade_line_id),
    CONSTRAINT ck_line_prices_1 CHECK (exchange_rate > 0),
    CONSTRAINT ck_line_prices_2 CHECK (currency = 'KRW' OR exchange_rate_date IS NOT NULL),
    CONSTRAINT ck_line_prices_3 CHECK (attribution_basis IN ('DOCUMENT_DATE', 'FULFILLED_DATE', 'MANUAL')),
    CONSTRAINT ck_line_prices_4 CHECK ((attribution_basis = 'MANUAL') = (attribution_date IS NOT NULL))
);

CREATE TABLE cost.extra_costs (
    id uuid NOT NULL DEFAULT uuidv7(),
    project_id uuid NOT NULL,
    cost_type varchar(20) NOT NULL,
    amount numeric(18,2) NOT NULL,
    currency char(3) NOT NULL DEFAULT 'KRW',
    exchange_rate numeric(18,6) NOT NULL DEFAULT 1,
    exchange_rate_date date,
    amount_krw numeric(18,2) NOT NULL,
    cost_date date NOT NULL,
    trade_document_id uuid,
    loan_document_id uuid,
    note text,
    attribution_basis varchar(20) NOT NULL DEFAULT 'COST_DATE',
    attribution_date date,
    created_at timestamptz NOT NULL DEFAULT now(),
    created_by uuid NOT NULL,
    updated_at timestamptz,
    updated_by uuid,
    version integer NOT NULL DEFAULT 0,
    deleted_at timestamptz,
    deleted_by uuid,
    CONSTRAINT pk_extra_costs PRIMARY KEY (id),
    CONSTRAINT ck_extra_costs_1 CHECK (cost_type IN ('SHIPPING', 'INSTALL', 'RENTAL', 'OTHER')),
    CONSTRAINT ck_extra_costs_2 CHECK (exchange_rate > 0),
    CONSTRAINT ck_extra_costs_3 CHECK (cost_type <> 'RENTAL' OR loan_document_id IS NOT NULL),
    CONSTRAINT ck_extra_costs_4 CHECK (currency = 'KRW' OR exchange_rate_date IS NOT NULL),
    CONSTRAINT ck_extra_costs_5 CHECK (attribution_basis IN ('COST_DATE', 'MANUAL')),
    CONSTRAINT ck_extra_costs_6 CHECK ((attribution_basis = 'MANUAL') = (attribution_date IS NOT NULL))
);

CREATE TABLE cost.loan_fees (
    loan_document_id uuid NOT NULL,
    amount numeric(18,2) NOT NULL,
    currency char(3) NOT NULL DEFAULT 'KRW',
    exchange_rate numeric(18,6) NOT NULL DEFAULT 1,
    exchange_rate_date date,
    amount_krw numeric(18,2) NOT NULL,
    attribution_basis varchar(20) NOT NULL DEFAULT 'SETTLED_DATE',
    attribution_date date,
    created_at timestamptz NOT NULL DEFAULT now(),
    created_by uuid NOT NULL,
    updated_at timestamptz,
    updated_by uuid,
    version integer NOT NULL DEFAULT 0,
    CONSTRAINT pk_loan_fees PRIMARY KEY (loan_document_id),
    CONSTRAINT ck_loan_fees_1 CHECK (exchange_rate > 0),
    CONSTRAINT ck_loan_fees_2 CHECK (currency = 'KRW' OR exchange_rate_date IS NOT NULL),
    CONSTRAINT ck_loan_fees_3 CHECK (attribution_basis IN ('SETTLED_DATE', 'DUE_DATE', 'MANUAL')),
    CONSTRAINT ck_loan_fees_4 CHECK ((attribution_basis = 'MANUAL') = (attribution_date IS NOT NULL))
);

CREATE TABLE cost.opening_costs (
    ledger_entry_id uuid NOT NULL,
    unit_cost numeric(19,4) NOT NULL,
    currency char(3) NOT NULL DEFAULT 'KRW',
    exchange_rate numeric(18,6) NOT NULL DEFAULT 1,
    exchange_rate_date date,
    unit_cost_krw numeric(19,4) NOT NULL,
    note text,
    attribution_basis varchar(20) NOT NULL DEFAULT 'CUTOVER_DATE',
    attribution_date date,
    created_at timestamptz NOT NULL DEFAULT now(),
    created_by uuid NOT NULL,
    updated_at timestamptz,
    updated_by uuid,
    version integer NOT NULL DEFAULT 0,
    CONSTRAINT pk_opening_costs PRIMARY KEY (ledger_entry_id),
    CONSTRAINT ck_opening_costs_1 CHECK (unit_cost >= 0),
    CONSTRAINT ck_opening_costs_2 CHECK (exchange_rate > 0),
    CONSTRAINT ck_opening_costs_3 CHECK (currency = 'KRW' OR exchange_rate_date IS NOT NULL),
    CONSTRAINT ck_opening_costs_4 CHECK (attribution_basis IN ('CUTOVER_DATE', 'MANUAL')),
    CONSTRAINT ck_opening_costs_5 CHECK ((attribution_basis = 'MANUAL') = (attribution_date IS NOT NULL))
);

CREATE TABLE cost.cost_changes (
    id uuid NOT NULL DEFAULT uuidv7(),
    target_type varchar(20) NOT NULL,
    target_id uuid NOT NULL,
    field_name varchar(50) NOT NULL,
    old_value text,
    new_value text,
    reason text,
    changed_by uuid NOT NULL,
    changed_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT pk_cost_changes PRIMARY KEY (id),
    CONSTRAINT ck_cost_changes_1 CHECK (target_type IN ('LINE_PRICE', 'EXTRA_COST', 'LOAN_FEE', 'OPENING_COST'))
);

CREATE TABLE importing.files (
    id uuid NOT NULL DEFAULT uuidv7(),
    target_type varchar(30) NOT NULL,
    target_id uuid NOT NULL,
    original_name varchar(300) NOT NULL,
    content_type varchar(100) NOT NULL,
    storage_key varchar(500) NOT NULL,
    content_hash varchar(64) NOT NULL,
    size_bytes bigint NOT NULL,
    uploaded_by uuid NOT NULL,
    uploaded_at timestamptz NOT NULL DEFAULT now(),
    note text,
    deleted_at timestamptz,
    deleted_by uuid,
    CONSTRAINT pk_files PRIMARY KEY (id),
    CONSTRAINT uq_files_storage_key UNIQUE (storage_key),
    CONSTRAINT ck_files_1 CHECK (target_type IN ('TRADE_DOCUMENT')),
    CONSTRAINT ck_files_2 CHECK (content_type IN ('application/pdf', 'image/jpeg', 'image/png')),
    CONSTRAINT ck_files_3 CHECK (size_bytes > 0 AND size_bytes <= 20971520)
);

CREATE TABLE common.idempotency_keys (
    idempotency_key varchar(64) NOT NULL,
    user_id uuid NOT NULL,
    action varchar(100) NOT NULL,
    request_hash varchar(64) NOT NULL,
    status varchar(20) NOT NULL DEFAULT 'IN_PROGRESS',
    response_status integer,
    response_body jsonb,
    created_at timestamptz NOT NULL DEFAULT now(),
    completed_at timestamptz,
    CONSTRAINT pk_idempotency_keys PRIMARY KEY (idempotency_key),
    CONSTRAINT ck_idempotency_keys_1 CHECK (status IN ('IN_PROGRESS', 'DONE')),
    CONSTRAINT ck_idempotency_keys_2 CHECK (status = 'IN_PROGRESS' OR (response_status IS NOT NULL AND completed_at IS NOT NULL))
);

CREATE TABLE admin.review_requests (
    id uuid NOT NULL DEFAULT uuidv7(),
    request_type varchar(30) NOT NULL,
    target_type varchar(30) NOT NULL,
    target_id uuid NOT NULL,
    status varchar(20) NOT NULL DEFAULT 'PENDING',
    summary text,
    requested_by uuid NOT NULL,
    requested_at timestamptz NOT NULL DEFAULT now(),
    decided_by uuid,
    decided_at timestamptz,
    decision_reason text,
    version integer NOT NULL DEFAULT 0,
    CONSTRAINT pk_review_requests PRIMARY KEY (id),
    CONSTRAINT ck_review_requests_1 CHECK (request_type IN ('DISPOSAL', 'LOAN_OUT', 'EQUIVALENT_SETTLEMENT', 'COUNT_DIFFERENCE', 'UNPLANNED_RECEIPT', 'SERIAL_CHANGE', 'LOAN_DUE_CHANGE')),
    CONSTRAINT ck_review_requests_2 CHECK (status IN ('PENDING', 'APPROVED', 'REJECTED', 'CONFIRMED')),
    CONSTRAINT ck_review_requests_3 CHECK (status NOT IN ('APPROVED', 'REJECTED') OR request_type IN ('DISPOSAL', 'LOAN_OUT', 'EQUIVALENT_SETTLEMENT', 'COUNT_DIFFERENCE')),
    CONSTRAINT ck_review_requests_4 CHECK (status <> 'CONFIRMED' OR request_type IN ('UNPLANNED_RECEIPT', 'SERIAL_CHANGE', 'LOAN_DUE_CHANGE')),
    CONSTRAINT ck_review_requests_5 CHECK (status = 'PENDING' OR (decided_by IS NOT NULL AND decided_at IS NOT NULL)),
    CONSTRAINT ck_review_requests_6 CHECK (status <> 'REJECTED' OR decision_reason IS NOT NULL)
);

CREATE TABLE admin.notifications (
    id uuid NOT NULL DEFAULT uuidv7(),
    recipient_user_id uuid NOT NULL,
    notification_type varchar(30) NOT NULL,
    title varchar(200) NOT NULL,
    message text,
    target_type varchar(30),
    target_id uuid,
    created_at timestamptz NOT NULL DEFAULT now(),
    read_at timestamptz,
    CONSTRAINT pk_notifications PRIMARY KEY (id),
    CONSTRAINT ck_notifications_1 CHECK (notification_type IN ('REVIEW_REJECTED', 'INTEGRITY_ALERT', 'ALLOCATION_RELEASED', 'WARRANTY_EXPIRING'))
);

CREATE TABLE admin.integrity_check_results (
    id uuid NOT NULL DEFAULT uuidv7(),
    check_code varchar(10) NOT NULL,
    target_type varchar(30) NOT NULL,
    target_key varchar(200) NOT NULL,
    detail jsonb NOT NULL,
    first_found_at timestamptz NOT NULL DEFAULT now(),
    last_found_at timestamptz NOT NULL DEFAULT now(),
    resolved_at timestamptz,
    CONSTRAINT pk_integrity_check_results PRIMARY KEY (id),
    CONSTRAINT ck_integrity_check_results_1 CHECK (resolved_at IS NULL OR resolved_at >= first_found_at)
);

-- ---------------------------------------------------------------- 외래 키
ALTER TABLE auth.user_roles ADD CONSTRAINT fk_user_roles_user_id FOREIGN KEY (user_id) REFERENCES auth.users (id);
ALTER TABLE auth.user_roles ADD CONSTRAINT fk_user_roles_role_id FOREIGN KEY (role_id) REFERENCES auth.roles (id);
ALTER TABLE auth.user_permissions ADD CONSTRAINT fk_user_permissions_user_id FOREIGN KEY (user_id) REFERENCES auth.users (id);
ALTER TABLE product.products ADD CONSTRAINT fk_products_category_id FOREIGN KEY (category_id) REFERENCES product.product_categories (id);
ALTER TABLE product.product_changes ADD CONSTRAINT fk_product_changes_product_id FOREIGN KEY (product_id) REFERENCES product.products (id);
ALTER TABLE product.bundle_components ADD CONSTRAINT fk_bundle_components_bundle_id FOREIGN KEY (bundle_id) REFERENCES product.bundles (id);
ALTER TABLE product.bundle_components ADD CONSTRAINT fk_bundle_components_product_id FOREIGN KEY (product_id) REFERENCES product.products (id);
ALTER TABLE warehouse.locations ADD CONSTRAINT fk_locations_warehouse_id FOREIGN KEY (warehouse_id) REFERENCES warehouse.warehouses (id);
ALTER TABLE warehouse.locations ADD CONSTRAINT fk_locations_partner_id FOREIGN KEY (partner_id) REFERENCES partner.partners (id);
ALTER TABLE partner.partner_roles ADD CONSTRAINT fk_partner_roles_partner_id FOREIGN KEY (partner_id) REFERENCES partner.partners (id);
ALTER TABLE partner.contacts ADD CONSTRAINT fk_contacts_partner_id FOREIGN KEY (partner_id) REFERENCES partner.partners (id);
ALTER TABLE inventory.stock_transactions ADD CONSTRAINT fk_stock_transactions_related_transaction_id FOREIGN KEY (related_transaction_id) REFERENCES inventory.stock_transactions (id);
ALTER TABLE inventory.stock_transactions ADD CONSTRAINT fk_stock_transactions_counterparty_partner_id FOREIGN KEY (counterparty_partner_id) REFERENCES partner.partners (id);
ALTER TABLE inventory.ledger_entries ADD CONSTRAINT fk_ledger_entries_transaction_id FOREIGN KEY (transaction_id) REFERENCES inventory.stock_transactions (id);
ALTER TABLE inventory.ledger_entries ADD CONSTRAINT fk_ledger_entries_product_id FOREIGN KEY (product_id) REFERENCES product.products (id);
ALTER TABLE inventory.ledger_entries ADD CONSTRAINT fk_ledger_entries_location_id FOREIGN KEY (location_id) REFERENCES warehouse.locations (id);
ALTER TABLE inventory.ledger_entries ADD CONSTRAINT fk_ledger_entries_owner_partner_id FOREIGN KEY (owner_partner_id) REFERENCES partner.partners (id);
ALTER TABLE inventory.ledger_entries ADD CONSTRAINT fk_ledger_entries_equipment_id FOREIGN KEY (equipment_id) REFERENCES equipment.equipment (id);
ALTER TABLE inventory.ledger_entries ADD CONSTRAINT fk_ledger_entries_reversal_of_entry_id FOREIGN KEY (reversal_of_entry_id) REFERENCES inventory.ledger_entries (id);
ALTER TABLE inventory.stock_balances ADD CONSTRAINT fk_stock_balances_product_id FOREIGN KEY (product_id) REFERENCES product.products (id);
ALTER TABLE inventory.stock_balances ADD CONSTRAINT fk_stock_balances_location_id FOREIGN KEY (location_id) REFERENCES warehouse.locations (id);
ALTER TABLE inventory.stock_balances ADD CONSTRAINT fk_stock_balances_owner_partner_id FOREIGN KEY (owner_partner_id) REFERENCES partner.partners (id);
ALTER TABLE inventory.period_closing_events ADD CONSTRAINT fk_period_closing_events_period FOREIGN KEY (period) REFERENCES inventory.period_closings (period);
ALTER TABLE inventory.monthly_stock_snapshots ADD CONSTRAINT fk_monthly_stock_snapshots_product_id FOREIGN KEY (product_id) REFERENCES product.products (id);
ALTER TABLE inventory.monthly_stock_snapshots ADD CONSTRAINT fk_monthly_stock_snapshots_location_id FOREIGN KEY (location_id) REFERENCES warehouse.locations (id);
ALTER TABLE inventory.monthly_stock_snapshots ADD CONSTRAINT fk_monthly_stock_snapshots_owner_partner_id FOREIGN KEY (owner_partner_id) REFERENCES partner.partners (id);
ALTER TABLE inventory.stock_counts ADD CONSTRAINT fk_stock_counts_adjustment_transaction_id FOREIGN KEY (adjustment_transaction_id) REFERENCES inventory.stock_transactions (id);
ALTER TABLE inventory.stock_count_scopes ADD CONSTRAINT fk_stock_count_scopes_count_id FOREIGN KEY (count_id) REFERENCES inventory.stock_counts (id);
ALTER TABLE inventory.stock_count_scopes ADD CONSTRAINT fk_stock_count_scopes_location_id FOREIGN KEY (location_id) REFERENCES warehouse.locations (id);
ALTER TABLE inventory.stock_count_scopes ADD CONSTRAINT fk_stock_count_scopes_product_id FOREIGN KEY (product_id) REFERENCES product.products (id);
ALTER TABLE inventory.stock_count_lines ADD CONSTRAINT fk_stock_count_lines_count_id FOREIGN KEY (count_id) REFERENCES inventory.stock_counts (id);
ALTER TABLE inventory.stock_count_lines ADD CONSTRAINT fk_stock_count_lines_product_id FOREIGN KEY (product_id) REFERENCES product.products (id);
ALTER TABLE inventory.stock_count_lines ADD CONSTRAINT fk_stock_count_lines_location_id FOREIGN KEY (location_id) REFERENCES warehouse.locations (id);
ALTER TABLE inventory.stock_count_lines ADD CONSTRAINT fk_stock_count_lines_owner_partner_id FOREIGN KEY (owner_partner_id) REFERENCES partner.partners (id);
ALTER TABLE inventory.stock_count_serials ADD CONSTRAINT fk_stock_count_serials_count_id FOREIGN KEY (count_id) REFERENCES inventory.stock_counts (id);
ALTER TABLE inventory.stock_count_serials ADD CONSTRAINT fk_stock_count_serials_line_id FOREIGN KEY (line_id) REFERENCES inventory.stock_count_lines (id);
ALTER TABLE inventory.stock_count_serials ADD CONSTRAINT fk_stock_count_serials_equipment_id FOREIGN KEY (equipment_id) REFERENCES equipment.equipment (id);
ALTER TABLE equipment.equipment ADD CONSTRAINT fk_equipment_product_id FOREIGN KEY (product_id) REFERENCES product.products (id);
ALTER TABLE equipment.equipment ADD CONSTRAINT fk_equipment_current_location_id FOREIGN KEY (current_location_id) REFERENCES warehouse.locations (id);
ALTER TABLE equipment.equipment ADD CONSTRAINT fk_equipment_owner_partner_id FOREIGN KEY (owner_partner_id) REFERENCES partner.partners (id);
ALTER TABLE equipment.equipment ADD CONSTRAINT fk_equipment_project_id FOREIGN KEY (project_id) REFERENCES project.projects (id);
ALTER TABLE equipment.equipment ADD CONSTRAINT fk_equipment_delivered_partner_id FOREIGN KEY (delivered_partner_id) REFERENCES partner.partners (id);
ALTER TABLE equipment.equipment ADD CONSTRAINT fk_equipment_replaced_by_equipment_id FOREIGN KEY (replaced_by_equipment_id) REFERENCES equipment.equipment (id);
ALTER TABLE equipment.equipment_events ADD CONSTRAINT fk_equipment_events_equipment_id FOREIGN KEY (equipment_id) REFERENCES equipment.equipment (id);
ALTER TABLE equipment.equipment_events ADD CONSTRAINT fk_equipment_events_from_location_id FOREIGN KEY (from_location_id) REFERENCES warehouse.locations (id);
ALTER TABLE equipment.equipment_events ADD CONSTRAINT fk_equipment_events_to_location_id FOREIGN KEY (to_location_id) REFERENCES warehouse.locations (id);
ALTER TABLE equipment.equipment_events ADD CONSTRAINT fk_equipment_events_ledger_entry_id FOREIGN KEY (ledger_entry_id) REFERENCES inventory.ledger_entries (id);
ALTER TABLE equipment.warranties ADD CONSTRAINT fk_warranties_equipment_id FOREIGN KEY (equipment_id) REFERENCES equipment.equipment (id);
ALTER TABLE equipment.warranties ADD CONSTRAINT fk_warranties_inherited_from_equipment_id FOREIGN KEY (inherited_from_equipment_id) REFERENCES equipment.equipment (id);
ALTER TABLE equipment.warranty_changes ADD CONSTRAINT fk_warranty_changes_warranty_id FOREIGN KEY (warranty_id) REFERENCES equipment.warranties (id);
ALTER TABLE project.projects ADD CONSTRAINT fk_projects_customer_partner_id FOREIGN KEY (customer_partner_id) REFERENCES partner.partners (id);
ALTER TABLE project.trade_documents ADD CONSTRAINT fk_trade_documents_project_id FOREIGN KEY (project_id) REFERENCES project.projects (id);
ALTER TABLE project.trade_documents ADD CONSTRAINT fk_trade_documents_partner_id FOREIGN KEY (partner_id) REFERENCES partner.partners (id);
ALTER TABLE project.trade_documents ADD CONSTRAINT fk_trade_documents_copied_from_document_id FOREIGN KEY (copied_from_document_id) REFERENCES project.trade_documents (id);
ALTER TABLE project.trade_lines ADD CONSTRAINT fk_trade_lines_document_id FOREIGN KEY (document_id) REFERENCES project.trade_documents (id);
ALTER TABLE project.trade_lines ADD CONSTRAINT fk_trade_lines_product_id FOREIGN KEY (product_id) REFERENCES product.products (id);
ALTER TABLE project.trade_document_changes ADD CONSTRAINT fk_trade_document_changes_document_id FOREIGN KEY (document_id) REFERENCES project.trade_documents (id);
ALTER TABLE project.trade_document_changes ADD CONSTRAINT fk_trade_document_changes_line_id FOREIGN KEY (line_id) REFERENCES project.trade_lines (id);
ALTER TABLE allocation.allocations ADD CONSTRAINT fk_allocations_product_id FOREIGN KEY (product_id) REFERENCES product.products (id);
ALTER TABLE allocation.allocations ADD CONSTRAINT fk_allocations_project_id FOREIGN KEY (project_id) REFERENCES project.projects (id);
ALTER TABLE allocation.allocations ADD CONSTRAINT fk_allocations_loan_document_id FOREIGN KEY (loan_document_id) REFERENCES loan.loan_documents (id);
ALTER TABLE allocation.allocations ADD CONSTRAINT fk_allocations_source_trade_line_id FOREIGN KEY (source_trade_line_id) REFERENCES project.trade_lines (id);
ALTER TABLE allocation.allocations ADD CONSTRAINT fk_allocations_owner_partner_id FOREIGN KEY (owner_partner_id) REFERENCES partner.partners (id);
ALTER TABLE allocation.allocations ADD CONSTRAINT fk_allocations_equipment_id FOREIGN KEY (equipment_id) REFERENCES equipment.equipment (id);
ALTER TABLE allocation.allocation_events ADD CONSTRAINT fk_allocation_events_allocation_id FOREIGN KEY (allocation_id) REFERENCES allocation.allocations (id);
ALTER TABLE delivery.deliveries ADD CONSTRAINT fk_deliveries_project_id FOREIGN KEY (project_id) REFERENCES project.projects (id);
ALTER TABLE delivery.deliveries ADD CONSTRAINT fk_deliveries_sales_document_id FOREIGN KEY (sales_document_id) REFERENCES project.trade_documents (id);
ALTER TABLE delivery.deliveries ADD CONSTRAINT fk_deliveries_customer_partner_id FOREIGN KEY (customer_partner_id) REFERENCES partner.partners (id);
ALTER TABLE delivery.deliveries ADD CONSTRAINT fk_deliveries_bundle_id FOREIGN KEY (bundle_id) REFERENCES product.bundles (id);
ALTER TABLE delivery.deliveries ADD CONSTRAINT fk_deliveries_transaction_id FOREIGN KEY (transaction_id) REFERENCES inventory.stock_transactions (id);
ALTER TABLE delivery.delivery_lines ADD CONSTRAINT fk_delivery_lines_delivery_id FOREIGN KEY (delivery_id) REFERENCES delivery.deliveries (id);
ALTER TABLE delivery.delivery_lines ADD CONSTRAINT fk_delivery_lines_product_id FOREIGN KEY (product_id) REFERENCES product.products (id);
ALTER TABLE delivery.delivery_lines ADD CONSTRAINT fk_delivery_lines_sales_line_id FOREIGN KEY (sales_line_id) REFERENCES project.trade_lines (id);
ALTER TABLE delivery.delivery_lines ADD CONSTRAINT fk_delivery_lines_purchase_line_id FOREIGN KEY (purchase_line_id) REFERENCES project.trade_lines (id);
ALTER TABLE delivery.delivery_lines ADD CONSTRAINT fk_delivery_lines_loan_line_id FOREIGN KEY (loan_line_id) REFERENCES loan.loan_lines (id);
ALTER TABLE delivery.delivery_lines ADD CONSTRAINT fk_delivery_lines_equipment_id FOREIGN KEY (equipment_id) REFERENCES equipment.equipment (id);
ALTER TABLE delivery.delivery_returns ADD CONSTRAINT fk_delivery_returns_delivery_line_id FOREIGN KEY (delivery_line_id) REFERENCES delivery.delivery_lines (id);
ALTER TABLE delivery.delivery_returns ADD CONSTRAINT fk_delivery_returns_equipment_id FOREIGN KEY (equipment_id) REFERENCES equipment.equipment (id);
ALTER TABLE delivery.delivery_returns ADD CONSTRAINT fk_delivery_returns_transaction_id FOREIGN KEY (transaction_id) REFERENCES inventory.stock_transactions (id);
ALTER TABLE loan.loan_documents ADD CONSTRAINT fk_loan_documents_partner_id FOREIGN KEY (partner_id) REFERENCES partner.partners (id);
ALTER TABLE loan.loan_documents ADD CONSTRAINT fk_loan_documents_project_id FOREIGN KEY (project_id) REFERENCES project.projects (id);
ALTER TABLE loan.loan_documents ADD CONSTRAINT fk_loan_documents_converted_trade_document_id FOREIGN KEY (converted_trade_document_id) REFERENCES project.trade_documents (id);
ALTER TABLE loan.loan_lines ADD CONSTRAINT fk_loan_lines_loan_id FOREIGN KEY (loan_id) REFERENCES loan.loan_documents (id);
ALTER TABLE loan.loan_lines ADD CONSTRAINT fk_loan_lines_product_id FOREIGN KEY (product_id) REFERENCES product.products (id);
ALTER TABLE loan.loan_lines ADD CONSTRAINT fk_loan_lines_equipment_id FOREIGN KEY (equipment_id) REFERENCES equipment.equipment (id);
ALTER TABLE loan.loan_settlements ADD CONSTRAINT fk_loan_settlements_loan_line_id FOREIGN KEY (loan_line_id) REFERENCES loan.loan_lines (id);
ALTER TABLE loan.loan_settlements ADD CONSTRAINT fk_loan_settlements_settled_product_id FOREIGN KEY (settled_product_id) REFERENCES product.products (id);
ALTER TABLE loan.loan_settlements ADD CONSTRAINT fk_loan_settlements_equipment_id FOREIGN KEY (equipment_id) REFERENCES equipment.equipment (id);
ALTER TABLE loan.loan_settlements ADD CONSTRAINT fk_loan_settlements_transaction_id FOREIGN KEY (transaction_id) REFERENCES inventory.stock_transactions (id);
ALTER TABLE loan.loan_settlements ADD CONSTRAINT fk_loan_settlements_trade_document_id FOREIGN KEY (trade_document_id) REFERENCES project.trade_documents (id);
ALTER TABLE loan.loan_document_changes ADD CONSTRAINT fk_loan_document_changes_loan_id FOREIGN KEY (loan_id) REFERENCES loan.loan_documents (id);
ALTER TABLE loan.loan_document_changes ADD CONSTRAINT fk_loan_document_changes_line_id FOREIGN KEY (line_id) REFERENCES loan.loan_lines (id);
ALTER TABLE cost.line_prices ADD CONSTRAINT fk_line_prices_trade_line_id FOREIGN KEY (trade_line_id) REFERENCES project.trade_lines (id);
ALTER TABLE cost.line_prices ADD CONSTRAINT fk_line_prices_currency FOREIGN KEY (currency) REFERENCES cost.currencies (code);
ALTER TABLE cost.extra_costs ADD CONSTRAINT fk_extra_costs_project_id FOREIGN KEY (project_id) REFERENCES project.projects (id);
ALTER TABLE cost.extra_costs ADD CONSTRAINT fk_extra_costs_currency FOREIGN KEY (currency) REFERENCES cost.currencies (code);
ALTER TABLE cost.extra_costs ADD CONSTRAINT fk_extra_costs_trade_document_id FOREIGN KEY (trade_document_id) REFERENCES project.trade_documents (id);
ALTER TABLE cost.extra_costs ADD CONSTRAINT fk_extra_costs_loan_document_id FOREIGN KEY (loan_document_id) REFERENCES loan.loan_documents (id);
ALTER TABLE cost.loan_fees ADD CONSTRAINT fk_loan_fees_loan_document_id FOREIGN KEY (loan_document_id) REFERENCES loan.loan_documents (id);
ALTER TABLE cost.loan_fees ADD CONSTRAINT fk_loan_fees_currency FOREIGN KEY (currency) REFERENCES cost.currencies (code);
ALTER TABLE cost.opening_costs ADD CONSTRAINT fk_opening_costs_ledger_entry_id FOREIGN KEY (ledger_entry_id) REFERENCES inventory.ledger_entries (id);
ALTER TABLE cost.opening_costs ADD CONSTRAINT fk_opening_costs_currency FOREIGN KEY (currency) REFERENCES cost.currencies (code);

-- ---------------------------------------------------------------- 조회 인덱스
CREATE INDEX ix_user_roles_user_id ON auth.user_roles (user_id);
CREATE INDEX ix_user_roles_role_id ON auth.user_roles (role_id);
CREATE INDEX ix_user_permissions_user_id ON auth.user_permissions (user_id);
CREATE INDEX ix_products_category_id ON product.products (category_id);
CREATE INDEX ix_product_changes_product_id ON product.product_changes (product_id);
CREATE INDEX ix_bundle_components_bundle_id ON product.bundle_components (bundle_id);
CREATE INDEX ix_bundle_components_product_id ON product.bundle_components (product_id);
CREATE INDEX ix_locations_warehouse_id ON warehouse.locations (warehouse_id);
CREATE INDEX ix_locations_partner_id ON warehouse.locations (partner_id);
CREATE INDEX ix_partner_roles_partner_id ON partner.partner_roles (partner_id);
CREATE INDEX ix_contacts_partner_id ON partner.contacts (partner_id);
CREATE INDEX ix_stock_transactions_related_transaction_id ON inventory.stock_transactions (related_transaction_id);
CREATE INDEX ix_stock_transactions_counterparty_partner_id ON inventory.stock_transactions (counterparty_partner_id);
CREATE INDEX ix_ledger_entries_product_id_location_id_stock_condition_o ON inventory.ledger_entries (product_id, location_id, stock_condition, owner_type, owner_partner_id, business_date);
CREATE INDEX ix_ledger_entries_transaction_id ON inventory.ledger_entries (transaction_id);
CREATE INDEX ix_ledger_entries_product_id ON inventory.ledger_entries (product_id);
CREATE INDEX ix_ledger_entries_location_id ON inventory.ledger_entries (location_id);
CREATE INDEX ix_ledger_entries_owner_partner_id ON inventory.ledger_entries (owner_partner_id);
CREATE INDEX ix_ledger_entries_equipment_id ON inventory.ledger_entries (equipment_id);
CREATE INDEX ix_ledger_entries_reversal_of_entry_id ON inventory.ledger_entries (reversal_of_entry_id);
CREATE INDEX ix_stock_balances_product_id ON inventory.stock_balances (product_id);
CREATE INDEX ix_stock_balances_location_id ON inventory.stock_balances (location_id);
CREATE INDEX ix_stock_balances_owner_partner_id ON inventory.stock_balances (owner_partner_id);
CREATE INDEX ix_period_closing_events_period ON inventory.period_closing_events (period);
CREATE INDEX ix_monthly_stock_snapshots_product_id ON inventory.monthly_stock_snapshots (product_id);
CREATE INDEX ix_monthly_stock_snapshots_location_id ON inventory.monthly_stock_snapshots (location_id);
CREATE INDEX ix_monthly_stock_snapshots_owner_partner_id ON inventory.monthly_stock_snapshots (owner_partner_id);
CREATE INDEX ix_stock_counts_adjustment_transaction_id ON inventory.stock_counts (adjustment_transaction_id);
CREATE INDEX ix_stock_count_scopes_count_id ON inventory.stock_count_scopes (count_id);
CREATE INDEX ix_stock_count_scopes_location_id ON inventory.stock_count_scopes (location_id);
CREATE INDEX ix_stock_count_scopes_product_id ON inventory.stock_count_scopes (product_id);
CREATE INDEX ix_stock_count_lines_count_id ON inventory.stock_count_lines (count_id);
CREATE INDEX ix_stock_count_lines_product_id ON inventory.stock_count_lines (product_id);
CREATE INDEX ix_stock_count_lines_location_id ON inventory.stock_count_lines (location_id);
CREATE INDEX ix_stock_count_lines_owner_partner_id ON inventory.stock_count_lines (owner_partner_id);
CREATE INDEX ix_stock_count_serials_count_id ON inventory.stock_count_serials (count_id);
CREATE INDEX ix_stock_count_serials_line_id ON inventory.stock_count_serials (line_id);
CREATE INDEX ix_stock_count_serials_equipment_id ON inventory.stock_count_serials (equipment_id);
CREATE INDEX ix_equipment_product_id ON equipment.equipment (product_id);
CREATE INDEX ix_equipment_current_location_id ON equipment.equipment (current_location_id);
CREATE INDEX ix_equipment_owner_partner_id ON equipment.equipment (owner_partner_id);
CREATE INDEX ix_equipment_project_id ON equipment.equipment (project_id);
CREATE INDEX ix_equipment_delivered_partner_id ON equipment.equipment (delivered_partner_id);
CREATE INDEX ix_equipment_replaced_by_equipment_id ON equipment.equipment (replaced_by_equipment_id);
CREATE INDEX ix_equipment_events_equipment_id_business_date ON equipment.equipment_events (equipment_id, business_date);
CREATE INDEX ix_equipment_events_equipment_id ON equipment.equipment_events (equipment_id);
CREATE INDEX ix_equipment_events_from_location_id ON equipment.equipment_events (from_location_id);
CREATE INDEX ix_equipment_events_to_location_id ON equipment.equipment_events (to_location_id);
CREATE INDEX ix_equipment_events_ledger_entry_id ON equipment.equipment_events (ledger_entry_id);
CREATE INDEX ix_warranties_equipment_id ON equipment.warranties (equipment_id);
CREATE INDEX ix_warranties_inherited_from_equipment_id ON equipment.warranties (inherited_from_equipment_id);
CREATE INDEX ix_warranty_changes_warranty_id ON equipment.warranty_changes (warranty_id);
CREATE INDEX ix_projects_customer_partner_id ON project.projects (customer_partner_id);
CREATE INDEX ix_trade_documents_project_id ON project.trade_documents (project_id);
CREATE INDEX ix_trade_documents_partner_id ON project.trade_documents (partner_id);
CREATE INDEX ix_trade_documents_copied_from_document_id ON project.trade_documents (copied_from_document_id);
CREATE INDEX ix_trade_lines_document_id ON project.trade_lines (document_id);
CREATE INDEX ix_trade_lines_product_id ON project.trade_lines (product_id);
CREATE INDEX ix_trade_document_changes_document_id ON project.trade_document_changes (document_id);
CREATE INDEX ix_trade_document_changes_line_id ON project.trade_document_changes (line_id);
CREATE INDEX ix_allocations_product_id ON allocation.allocations (product_id);
CREATE INDEX ix_allocations_project_id ON allocation.allocations (project_id);
CREATE INDEX ix_allocations_loan_document_id ON allocation.allocations (loan_document_id);
CREATE INDEX ix_allocations_source_trade_line_id ON allocation.allocations (source_trade_line_id);
CREATE INDEX ix_allocations_owner_partner_id ON allocation.allocations (owner_partner_id);
CREATE INDEX ix_allocations_equipment_id ON allocation.allocations (equipment_id);
CREATE INDEX ix_allocation_events_allocation_id ON allocation.allocation_events (allocation_id);
CREATE INDEX ix_deliveries_project_id ON delivery.deliveries (project_id);
CREATE INDEX ix_deliveries_sales_document_id ON delivery.deliveries (sales_document_id);
CREATE INDEX ix_deliveries_customer_partner_id ON delivery.deliveries (customer_partner_id);
CREATE INDEX ix_deliveries_bundle_id ON delivery.deliveries (bundle_id);
CREATE INDEX ix_deliveries_transaction_id ON delivery.deliveries (transaction_id);
CREATE INDEX ix_delivery_lines_delivery_id ON delivery.delivery_lines (delivery_id);
CREATE INDEX ix_delivery_lines_product_id ON delivery.delivery_lines (product_id);
CREATE INDEX ix_delivery_lines_sales_line_id ON delivery.delivery_lines (sales_line_id);
CREATE INDEX ix_delivery_lines_purchase_line_id ON delivery.delivery_lines (purchase_line_id);
CREATE INDEX ix_delivery_lines_loan_line_id ON delivery.delivery_lines (loan_line_id);
CREATE INDEX ix_delivery_lines_equipment_id ON delivery.delivery_lines (equipment_id);
CREATE INDEX ix_delivery_returns_delivery_line_id ON delivery.delivery_returns (delivery_line_id);
CREATE INDEX ix_delivery_returns_equipment_id ON delivery.delivery_returns (equipment_id);
CREATE INDEX ix_delivery_returns_transaction_id ON delivery.delivery_returns (transaction_id);
CREATE INDEX ix_loan_documents_partner_id ON loan.loan_documents (partner_id);
CREATE INDEX ix_loan_documents_project_id ON loan.loan_documents (project_id);
CREATE INDEX ix_loan_documents_converted_trade_document_id ON loan.loan_documents (converted_trade_document_id);
CREATE INDEX ix_loan_lines_loan_id ON loan.loan_lines (loan_id);
CREATE INDEX ix_loan_lines_product_id ON loan.loan_lines (product_id);
CREATE INDEX ix_loan_lines_equipment_id ON loan.loan_lines (equipment_id);
CREATE INDEX ix_loan_settlements_loan_line_id ON loan.loan_settlements (loan_line_id);
CREATE INDEX ix_loan_settlements_settled_product_id ON loan.loan_settlements (settled_product_id);
CREATE INDEX ix_loan_settlements_equipment_id ON loan.loan_settlements (equipment_id);
CREATE INDEX ix_loan_settlements_transaction_id ON loan.loan_settlements (transaction_id);
CREATE INDEX ix_loan_settlements_trade_document_id ON loan.loan_settlements (trade_document_id);
CREATE INDEX ix_loan_document_changes_loan_id ON loan.loan_document_changes (loan_id);
CREATE INDEX ix_loan_document_changes_line_id ON loan.loan_document_changes (line_id);
CREATE INDEX ix_trash_events_entity_type_entity_id ON trash.trash_events (entity_type, entity_id);
CREATE INDEX ix_line_prices_trade_line_id ON cost.line_prices (trade_line_id);
CREATE INDEX ix_line_prices_currency ON cost.line_prices (currency);
CREATE INDEX ix_extra_costs_project_id ON cost.extra_costs (project_id);
CREATE INDEX ix_extra_costs_currency ON cost.extra_costs (currency);
CREATE INDEX ix_extra_costs_trade_document_id ON cost.extra_costs (trade_document_id);
CREATE INDEX ix_extra_costs_loan_document_id ON cost.extra_costs (loan_document_id);
CREATE INDEX ix_loan_fees_loan_document_id ON cost.loan_fees (loan_document_id);
CREATE INDEX ix_loan_fees_currency ON cost.loan_fees (currency);
CREATE INDEX ix_opening_costs_ledger_entry_id ON cost.opening_costs (ledger_entry_id);
CREATE INDEX ix_opening_costs_currency ON cost.opening_costs (currency);
CREATE INDEX ix_cost_changes_target_type_target_id ON cost.cost_changes (target_type, target_id);
CREATE INDEX ix_files_target_type_target_id ON importing.files (target_type, target_id);
CREATE INDEX ix_files_content_hash ON importing.files (content_hash);
CREATE INDEX ix_idempotency_keys_created_at ON common.idempotency_keys (created_at);
CREATE INDEX ix_review_requests_status_request_type ON admin.review_requests (status, request_type);
CREATE INDEX ix_notifications_recipient_user_id_read_at ON admin.notifications (recipient_user_id, read_at);

-- ---------------------------------------------------------------- 트리거·부분 유니크
-- 로그인 ID로 사용자 1명을 찾는다(삭제된 계정 제외)
CREATE UNIQUE INDEX ux_users_login_id ON auth.users (login_id) WHERE deleted_at IS NULL;
-- ux_product_categories_code
CREATE UNIQUE INDEX ux_product_categories_code ON product.product_categories (code) WHERE deleted_at IS NULL;
-- ux_products_item_code
CREATE UNIQUE INDEX ux_products_item_code ON product.products (item_code) WHERE deleted_at IS NULL;
-- ux_bundles_bundle_code
CREATE UNIQUE INDEX ux_bundles_bundle_code ON product.bundles (bundle_code) WHERE deleted_at IS NULL;
-- ux_warehouses_warehouse_code
CREATE UNIQUE INDEX ux_warehouses_warehouse_code ON warehouse.warehouses (warehouse_code) WHERE deleted_at IS NULL;
-- ux_locations_location_code
CREATE UNIQUE INDEX ux_locations_location_code ON warehouse.locations (location_code) WHERE deleted_at IS NULL;
-- ux_partners_business_reg_no
CREATE UNIQUE INDEX ux_partners_business_reg_no ON partner.partners (business_reg_no) WHERE business_reg_no IS NOT NULL AND deleted_at IS NULL;
-- 원장 수정·삭제 차단 함수(INV-01)
CREATE OR REPLACE FUNCTION inventory.fn_ledger_entries_append_only()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    RAISE EXCEPTION 'inventory.ledger_entries is append-only (% not allowed)', TG_OP;
END;
$$;
-- 원장 수정·삭제 차단 트리거(INV-01)
CREATE TRIGGER trg_ledger_entries_append_only
    BEFORE UPDATE OR DELETE ON inventory.ledger_entries
    FOR EACH ROW EXECUTE FUNCTION inventory.fn_ledger_entries_append_only();
-- 현재 재고 업서트(ON CONFLICT) 대상 키(INV-05)
ALTER TABLE inventory.stock_balances ADD CONSTRAINT ux_stock_balances_key UNIQUE NULLS NOT DISTINCT (product_id, location_id, stock_condition, owner_type, owner_partner_id);
-- 스냅샷 버전별 재고 키 1행
ALTER TABLE inventory.monthly_stock_snapshots ADD CONSTRAINT ux_monthly_stock_snapshots_key UNIQUE NULLS NOT DISTINCT (period, snapshot_version, product_id, location_id, stock_condition, owner_type, owner_partner_id);
-- ux_equipment_product_serial
CREATE UNIQUE INDEX ux_equipment_product_serial ON equipment.equipment (product_id, serial_no) WHERE serial_no IS NOT NULL;
-- ux_trade_documents_partner_docno
CREATE UNIQUE INDEX ux_trade_documents_partner_docno ON project.trade_documents (partner_id, document_no) WHERE deleted_at IS NULL AND document_no IS NOT NULL;
-- ux_review_requests_pending
CREATE UNIQUE INDEX ux_review_requests_pending ON admin.review_requests (request_type, target_type, target_id) WHERE status = 'PENDING';
-- ux_integrity_check_results_open
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

-- ---------------------------------------------------------------- 주석
COMMENT ON TABLE auth.users IS '사용자';
COMMENT ON COLUMN auth.users.id IS 'ID (UUID v7, 앱에서 생성. DB 기본값도 v7, PostgreSQL 18)';
COMMENT ON COLUMN auth.users.login_id IS '로그인 ID';
COMMENT ON COLUMN auth.users.name IS '이름';
COMMENT ON COLUMN auth.users.email IS '이메일';
COMMENT ON COLUMN auth.users.password_hash IS '비밀번호 해시';
COMMENT ON COLUMN auth.users.is_active IS '사용 여부';
COMMENT ON COLUMN auth.users.last_login_at IS '마지막 로그인';
COMMENT ON COLUMN auth.users.tokens_valid_after IS '토큰 무효 기준 시각';
COMMENT ON COLUMN auth.users.must_change_password IS '다음 로그인 때 비밀번호 변경 필요';
COMMENT ON COLUMN auth.users.created_at IS '생성 시각';
COMMENT ON COLUMN auth.users.created_by IS '생성자';
COMMENT ON COLUMN auth.users.updated_at IS '수정 시각';
COMMENT ON COLUMN auth.users.updated_by IS '수정자';
COMMENT ON COLUMN auth.users.version IS '버전(낙관적 잠금)';
COMMENT ON COLUMN auth.users.deleted_at IS '삭제 시각';
COMMENT ON COLUMN auth.users.deleted_by IS '삭제자';
COMMENT ON TABLE auth.roles IS '역할';
COMMENT ON COLUMN auth.roles.id IS 'ID (UUID v7, 앱에서 생성. DB 기본값도 v7, PostgreSQL 18)';
COMMENT ON COLUMN auth.roles.code IS '역할 코드';
COMMENT ON COLUMN auth.roles.name IS '역할명';
COMMENT ON TABLE auth.user_roles IS '사용자 역할';
COMMENT ON COLUMN auth.user_roles.user_id IS '사용자';
COMMENT ON COLUMN auth.user_roles.role_id IS '역할';
COMMENT ON TABLE auth.user_permissions IS '사용자 추가 권한';
COMMENT ON COLUMN auth.user_permissions.user_id IS '사용자';
COMMENT ON COLUMN auth.user_permissions.permission IS '권한(COST_VIEW/COST_EDIT)';
COMMENT ON TABLE auth.oauth2_authorization IS '로그인 토큰(Spring Authorization Server)';
COMMENT ON COLUMN auth.oauth2_authorization.id IS '인가 ID';
COMMENT ON COLUMN auth.oauth2_authorization.registered_client_id IS '클라이언트 ID';
COMMENT ON COLUMN auth.oauth2_authorization.principal_name IS '사용자(로그인 ID)';
COMMENT ON COLUMN auth.oauth2_authorization.authorization_grant_type IS '인가 방식';
COMMENT ON COLUMN auth.oauth2_authorization.authorized_scopes IS '허용 범위';
COMMENT ON COLUMN auth.oauth2_authorization.attributes IS '속성';
COMMENT ON COLUMN auth.oauth2_authorization.state IS '상태 값';
COMMENT ON COLUMN auth.oauth2_authorization.authorization_code_value IS '인가 코드';
COMMENT ON COLUMN auth.oauth2_authorization.authorization_code_issued_at IS '인가 코드 발급 시각';
COMMENT ON COLUMN auth.oauth2_authorization.authorization_code_expires_at IS '인가 코드 만료 시각';
COMMENT ON COLUMN auth.oauth2_authorization.authorization_code_metadata IS '인가 코드 메타데이터';
COMMENT ON COLUMN auth.oauth2_authorization.access_token_value IS 'access token';
COMMENT ON COLUMN auth.oauth2_authorization.access_token_issued_at IS 'access token 발급 시각';
COMMENT ON COLUMN auth.oauth2_authorization.access_token_expires_at IS 'access token 만료 시각';
COMMENT ON COLUMN auth.oauth2_authorization.access_token_metadata IS 'access token 메타데이터';
COMMENT ON COLUMN auth.oauth2_authorization.access_token_type IS 'access token 유형';
COMMENT ON COLUMN auth.oauth2_authorization.access_token_scopes IS 'access token 범위';
COMMENT ON COLUMN auth.oauth2_authorization.oidc_id_token_value IS 'ID 토큰';
COMMENT ON COLUMN auth.oauth2_authorization.oidc_id_token_issued_at IS 'ID 토큰 발급 시각';
COMMENT ON COLUMN auth.oauth2_authorization.oidc_id_token_expires_at IS 'ID 토큰 만료 시각';
COMMENT ON COLUMN auth.oauth2_authorization.oidc_id_token_metadata IS 'ID 토큰 메타데이터';
COMMENT ON COLUMN auth.oauth2_authorization.refresh_token_value IS 'refresh token';
COMMENT ON COLUMN auth.oauth2_authorization.refresh_token_issued_at IS 'refresh token 발급 시각';
COMMENT ON COLUMN auth.oauth2_authorization.refresh_token_expires_at IS 'refresh token 만료 시각';
COMMENT ON COLUMN auth.oauth2_authorization.refresh_token_metadata IS 'refresh token 메타데이터';
COMMENT ON COLUMN auth.oauth2_authorization.user_code_value IS '기기 인증 사용자 코드';
COMMENT ON COLUMN auth.oauth2_authorization.user_code_issued_at IS '사용자 코드 발급 시각';
COMMENT ON COLUMN auth.oauth2_authorization.user_code_expires_at IS '사용자 코드 만료 시각';
COMMENT ON COLUMN auth.oauth2_authorization.user_code_metadata IS '사용자 코드 메타데이터';
COMMENT ON COLUMN auth.oauth2_authorization.device_code_value IS '기기 코드';
COMMENT ON COLUMN auth.oauth2_authorization.device_code_issued_at IS '기기 코드 발급 시각';
COMMENT ON COLUMN auth.oauth2_authorization.device_code_expires_at IS '기기 코드 만료 시각';
COMMENT ON COLUMN auth.oauth2_authorization.device_code_metadata IS '기기 코드 메타데이터';
COMMENT ON TABLE product.product_categories IS '품목군';
COMMENT ON COLUMN product.product_categories.id IS 'ID (UUID v7, 앱에서 생성. DB 기본값도 v7, PostgreSQL 18)';
COMMENT ON COLUMN product.product_categories.code IS '품목군 코드';
COMMENT ON COLUMN product.product_categories.name IS '품목군명';
COMMENT ON COLUMN product.product_categories.sort_order IS '표시 순서';
COMMENT ON COLUMN product.product_categories.is_active IS '사용 여부';
COMMENT ON COLUMN product.product_categories.deleted_at IS '삭제 시각';
COMMENT ON COLUMN product.product_categories.deleted_by IS '삭제자';
COMMENT ON TABLE product.products IS '제품';
COMMENT ON COLUMN product.products.id IS 'ID (UUID v7, 앱에서 생성. DB 기본값도 v7, PostgreSQL 18)';
COMMENT ON COLUMN product.products.item_code IS 'Item Code(앞자리 0 보존)';
COMMENT ON COLUMN product.products.product_name IS '제품명';
COMMENT ON COLUMN product.products.model_name IS '모델명';
COMMENT ON COLUMN product.products.category_id IS '품목군';
COMMENT ON COLUMN product.products.manufacturer IS '제조사';
COMMENT ON COLUMN product.products.component_role IS '구성품 역할';
COMMENT ON COLUMN product.products.specification IS '규격/설명';
COMMENT ON COLUMN product.products.unit IS '단위';
COMMENT ON COLUMN product.products.serial_managed IS '시리얼 관리 여부';
COMMENT ON COLUMN product.products.is_active IS '사용 여부';
COMMENT ON COLUMN product.products.note IS '비고';
COMMENT ON COLUMN product.products.created_at IS '생성 시각';
COMMENT ON COLUMN product.products.created_by IS '생성자';
COMMENT ON COLUMN product.products.updated_at IS '수정 시각';
COMMENT ON COLUMN product.products.updated_by IS '수정자';
COMMENT ON COLUMN product.products.version IS '버전(낙관적 잠금)';
COMMENT ON COLUMN product.products.deleted_at IS '삭제 시각';
COMMENT ON COLUMN product.products.deleted_by IS '삭제자';
COMMENT ON TABLE product.product_changes IS '제품 변경 이력';
COMMENT ON COLUMN product.product_changes.id IS 'ID (UUID v7, 앱에서 생성. DB 기본값도 v7, PostgreSQL 18)';
COMMENT ON COLUMN product.product_changes.product_id IS '제품';
COMMENT ON COLUMN product.product_changes.field_name IS '변경 항목';
COMMENT ON COLUMN product.product_changes.old_value IS '이전 값';
COMMENT ON COLUMN product.product_changes.new_value IS '새 값';
COMMENT ON COLUMN product.product_changes.reason IS '사유';
COMMENT ON COLUMN product.product_changes.changed_by IS '변경자';
COMMENT ON COLUMN product.product_changes.changed_at IS '변경 시각';
COMMENT ON TABLE product.bundles IS '구성 묶음';
COMMENT ON COLUMN product.bundles.id IS 'ID (UUID v7, 앱에서 생성. DB 기본값도 v7, PostgreSQL 18)';
COMMENT ON COLUMN product.bundles.bundle_code IS '묶음 코드';
COMMENT ON COLUMN product.bundles.bundle_name IS '묶음명';
COMMENT ON COLUMN product.bundles.is_active IS '사용 여부';
COMMENT ON COLUMN product.bundles.note IS '비고';
COMMENT ON COLUMN product.bundles.created_at IS '생성 시각';
COMMENT ON COLUMN product.bundles.created_by IS '생성자';
COMMENT ON COLUMN product.bundles.updated_at IS '수정 시각';
COMMENT ON COLUMN product.bundles.updated_by IS '수정자';
COMMENT ON COLUMN product.bundles.version IS '버전(낙관적 잠금)';
COMMENT ON COLUMN product.bundles.deleted_at IS '삭제 시각';
COMMENT ON COLUMN product.bundles.deleted_by IS '삭제자';
COMMENT ON TABLE product.bundle_components IS '구성 묶음 구성품';
COMMENT ON COLUMN product.bundle_components.id IS 'ID (UUID v7, 앱에서 생성. DB 기본값도 v7, PostgreSQL 18)';
COMMENT ON COLUMN product.bundle_components.bundle_id IS '묶음';
COMMENT ON COLUMN product.bundle_components.product_id IS '구성품';
COMMENT ON COLUMN product.bundle_components.quantity_per_set IS '세트당 수량';
COMMENT ON TABLE warehouse.warehouses IS '창고';
COMMENT ON COLUMN warehouse.warehouses.id IS 'ID (UUID v7, 앱에서 생성. DB 기본값도 v7, PostgreSQL 18)';
COMMENT ON COLUMN warehouse.warehouses.warehouse_code IS '창고 코드';
COMMENT ON COLUMN warehouse.warehouses.warehouse_name IS '창고명';
COMMENT ON COLUMN warehouse.warehouses.address IS '주소';
COMMENT ON COLUMN warehouse.warehouses.is_active IS '사용 여부';
COMMENT ON COLUMN warehouse.warehouses.note IS '비고';
COMMENT ON COLUMN warehouse.warehouses.created_at IS '생성 시각';
COMMENT ON COLUMN warehouse.warehouses.created_by IS '생성자';
COMMENT ON COLUMN warehouse.warehouses.updated_at IS '수정 시각';
COMMENT ON COLUMN warehouse.warehouses.updated_by IS '수정자';
COMMENT ON COLUMN warehouse.warehouses.version IS '버전(낙관적 잠금)';
COMMENT ON COLUMN warehouse.warehouses.deleted_at IS '삭제 시각';
COMMENT ON COLUMN warehouse.warehouses.deleted_by IS '삭제자';
COMMENT ON TABLE warehouse.locations IS '위치(자사 창고 내 위치 + 외부 위치)';
COMMENT ON COLUMN warehouse.locations.id IS 'ID (UUID v7, 앱에서 생성. DB 기본값도 v7, PostgreSQL 18)';
COMMENT ON COLUMN warehouse.locations.location_code IS '위치 코드';
COMMENT ON COLUMN warehouse.locations.location_name IS '위치명';
COMMENT ON COLUMN warehouse.locations.location_type IS '위치 유형';
COMMENT ON COLUMN warehouse.locations.warehouse_id IS '창고(자사 위치)';
COMMENT ON COLUMN warehouse.locations.partner_id IS '상대 업체(외부 위치)';
COMMENT ON COLUMN warehouse.locations.zone IS '구역';
COMMENT ON COLUMN warehouse.locations.rack IS '랙';
COMMENT ON COLUMN warehouse.locations.shelf IS '선반';
COMMENT ON COLUMN warehouse.locations.is_active IS '사용 여부';
COMMENT ON COLUMN warehouse.locations.note IS '비고';
COMMENT ON COLUMN warehouse.locations.created_at IS '생성 시각';
COMMENT ON COLUMN warehouse.locations.created_by IS '생성자';
COMMENT ON COLUMN warehouse.locations.updated_at IS '수정 시각';
COMMENT ON COLUMN warehouse.locations.updated_by IS '수정자';
COMMENT ON COLUMN warehouse.locations.version IS '버전(낙관적 잠금)';
COMMENT ON COLUMN warehouse.locations.deleted_at IS '삭제 시각';
COMMENT ON COLUMN warehouse.locations.deleted_by IS '삭제자';
COMMENT ON TABLE partner.partners IS '거래처';
COMMENT ON COLUMN partner.partners.id IS 'ID (UUID v7, 앱에서 생성. DB 기본값도 v7, PostgreSQL 18)';
COMMENT ON COLUMN partner.partners.partner_name IS '거래처명';
COMMENT ON COLUMN partner.partners.business_reg_no IS '사업자등록번호';
COMMENT ON COLUMN partner.partners.address IS '주소';
COMMENT ON COLUMN partner.partners.phone IS '대표 번호';
COMMENT ON COLUMN partner.partners.is_active IS '사용 여부';
COMMENT ON COLUMN partner.partners.note IS '비고';
COMMENT ON COLUMN partner.partners.created_at IS '생성 시각';
COMMENT ON COLUMN partner.partners.created_by IS '생성자';
COMMENT ON COLUMN partner.partners.updated_at IS '수정 시각';
COMMENT ON COLUMN partner.partners.updated_by IS '수정자';
COMMENT ON COLUMN partner.partners.version IS '버전(낙관적 잠금)';
COMMENT ON COLUMN partner.partners.deleted_at IS '삭제 시각';
COMMENT ON COLUMN partner.partners.deleted_by IS '삭제자';
COMMENT ON TABLE partner.partner_roles IS '거래처 역할';
COMMENT ON COLUMN partner.partner_roles.partner_id IS '거래처';
COMMENT ON COLUMN partner.partner_roles.role IS '역할(고객사/공급사)';
COMMENT ON TABLE partner.contacts IS '거래처 담당자';
COMMENT ON COLUMN partner.contacts.id IS 'ID (UUID v7, 앱에서 생성. DB 기본값도 v7, PostgreSQL 18)';
COMMENT ON COLUMN partner.contacts.partner_id IS '거래처';
COMMENT ON COLUMN partner.contacts.name IS '담당자명';
COMMENT ON COLUMN partner.contacts.department IS '소속';
COMMENT ON COLUMN partner.contacts.position IS '직위';
COMMENT ON COLUMN partner.contacts.phone IS '번호';
COMMENT ON COLUMN partner.contacts.email IS '이메일';
COMMENT ON COLUMN partner.contacts.is_primary IS '주 담당자';
COMMENT ON COLUMN partner.contacts.created_at IS '생성 시각';
COMMENT ON COLUMN partner.contacts.created_by IS '생성자';
COMMENT ON COLUMN partner.contacts.updated_at IS '수정 시각';
COMMENT ON COLUMN partner.contacts.updated_by IS '수정자';
COMMENT ON COLUMN partner.contacts.version IS '버전(낙관적 잠금)';
COMMENT ON COLUMN partner.contacts.deleted_at IS '삭제 시각';
COMMENT ON COLUMN partner.contacts.deleted_by IS '삭제자';
COMMENT ON TABLE inventory.stock_transactions IS '처리 묶음(원장 헤더)';
COMMENT ON COLUMN inventory.stock_transactions.id IS 'ID (UUID v7, 앱에서 생성. DB 기본값도 v7, PostgreSQL 18)';
COMMENT ON COLUMN inventory.stock_transactions.transaction_no IS '처리 번호';
COMMENT ON COLUMN inventory.stock_transactions.transaction_type IS '처리 유형';
COMMENT ON COLUMN inventory.stock_transactions.business_date IS '업무 날짜';
COMMENT ON COLUMN inventory.stock_transactions.status IS '상태(임시/확정)';
COMMENT ON COLUMN inventory.stock_transactions.request_id IS '중복 요청 방지 키';
COMMENT ON COLUMN inventory.stock_transactions.related_transaction_id IS '취소·정정 원본 묶음';
COMMENT ON COLUMN inventory.stock_transactions.source_type IS '출처 유형';
COMMENT ON COLUMN inventory.stock_transactions.source_id IS '출처 ID';
COMMENT ON COLUMN inventory.stock_transactions.counterparty_partner_id IS '상대 거래처';
COMMENT ON COLUMN inventory.stock_transactions.reason_code IS '사유 코드';
COMMENT ON COLUMN inventory.stock_transactions.reason IS '사유';
COMMENT ON COLUMN inventory.stock_transactions.reference_no IS '외부 문서번호';
COMMENT ON COLUMN inventory.stock_transactions.approved_by IS '승인자';
COMMENT ON COLUMN inventory.stock_transactions.approved_at IS '승인 시각';
COMMENT ON COLUMN inventory.stock_transactions.note IS '비고';
COMMENT ON COLUMN inventory.stock_transactions.created_at IS '생성 시각';
COMMENT ON COLUMN inventory.stock_transactions.created_by IS '생성자';
COMMENT ON COLUMN inventory.stock_transactions.posted_at IS '확정 시각';
COMMENT ON COLUMN inventory.stock_transactions.posted_by IS '확정자';
COMMENT ON TABLE inventory.ledger_entries IS '재고 원장(INSERT 전용)';
COMMENT ON COLUMN inventory.ledger_entries.id IS 'ID (UUID v7, 앱에서 생성. DB 기본값도 v7, PostgreSQL 18)';
COMMENT ON COLUMN inventory.ledger_entries.transaction_id IS '처리 묶음';
COMMENT ON COLUMN inventory.ledger_entries.line_no IS '행 번호';
COMMENT ON COLUMN inventory.ledger_entries.product_id IS '제품';
COMMENT ON COLUMN inventory.ledger_entries.location_id IS '위치';
COMMENT ON COLUMN inventory.ledger_entries.stock_condition IS '재고 상태';
COMMENT ON COLUMN inventory.ledger_entries.owner_type IS '소유 구분(자사/타사)';
COMMENT ON COLUMN inventory.ledger_entries.owner_partner_id IS '타사 소유 업체';
COMMENT ON COLUMN inventory.ledger_entries.quantity_delta IS '수량 증감(+입고/-출고)';
COMMENT ON COLUMN inventory.ledger_entries.business_date IS '업무 날짜';
COMMENT ON COLUMN inventory.ledger_entries.equipment_id IS '개별 장비';
COMMENT ON COLUMN inventory.ledger_entries.pair_id IS '쌍 처리 묶음 ID';
COMMENT ON COLUMN inventory.ledger_entries.reversal_of_entry_id IS '취소 대상 원장 행';
COMMENT ON COLUMN inventory.ledger_entries.trade_line_id IS '연결 거래 품목(참조)';
COMMENT ON COLUMN inventory.ledger_entries.lot_no IS '로트 번호';
COMMENT ON COLUMN inventory.ledger_entries.item_code_snapshot IS '처리 당시 Item Code';
COMMENT ON COLUMN inventory.ledger_entries.product_name_snapshot IS '처리 당시 제품명';
COMMENT ON COLUMN inventory.ledger_entries.note IS '비고';
COMMENT ON COLUMN inventory.ledger_entries.created_at IS '생성 시각';
COMMENT ON COLUMN inventory.ledger_entries.created_by IS '생성자';
COMMENT ON TABLE inventory.stock_balances IS '현재 재고(잠금 대상)';
COMMENT ON COLUMN inventory.stock_balances.id IS 'ID (UUID v7, 앱에서 생성. DB 기본값도 v7, PostgreSQL 18)';
COMMENT ON COLUMN inventory.stock_balances.product_id IS '제품';
COMMENT ON COLUMN inventory.stock_balances.location_id IS '위치';
COMMENT ON COLUMN inventory.stock_balances.stock_condition IS '재고 상태';
COMMENT ON COLUMN inventory.stock_balances.owner_type IS '소유 구분(자사/타사)';
COMMENT ON COLUMN inventory.stock_balances.owner_partner_id IS '타사 소유 업체';
COMMENT ON COLUMN inventory.stock_balances.quantity IS '수량';
COMMENT ON COLUMN inventory.stock_balances.updated_at IS '갱신 시각';
COMMENT ON TABLE inventory.period_closings IS '월 마감';
COMMENT ON COLUMN inventory.period_closings.id IS 'ID (UUID v7, 앱에서 생성. DB 기본값도 v7, PostgreSQL 18)';
COMMENT ON COLUMN inventory.period_closings.period IS '기간(YYYY-MM)';
COMMENT ON COLUMN inventory.period_closings.status IS '상태';
COMMENT ON COLUMN inventory.period_closings.closed_at IS '마감 시각';
COMMENT ON COLUMN inventory.period_closings.closed_by IS '마감자';
COMMENT ON COLUMN inventory.period_closings.snapshot_version IS '스냅샷 버전';
COMMENT ON TABLE inventory.period_closing_events IS '마감·해제 이력';
COMMENT ON COLUMN inventory.period_closing_events.id IS 'ID (UUID v7, 앱에서 생성. DB 기본값도 v7, PostgreSQL 18)';
COMMENT ON COLUMN inventory.period_closing_events.period IS '기간';
COMMENT ON COLUMN inventory.period_closing_events.action IS '동작(마감/해제)';
COMMENT ON COLUMN inventory.period_closing_events.reason IS '사유';
COMMENT ON COLUMN inventory.period_closing_events.acted_by IS '처리자';
COMMENT ON COLUMN inventory.period_closing_events.acted_at IS '처리 시각';
COMMENT ON TABLE inventory.monthly_stock_snapshots IS '월말 재고 스냅샷';
COMMENT ON COLUMN inventory.monthly_stock_snapshots.id IS 'ID (UUID v7, 앱에서 생성. DB 기본값도 v7, PostgreSQL 18)';
COMMENT ON COLUMN inventory.monthly_stock_snapshots.period IS '기간';
COMMENT ON COLUMN inventory.monthly_stock_snapshots.snapshot_version IS '스냅샷 버전';
COMMENT ON COLUMN inventory.monthly_stock_snapshots.product_id IS '제품';
COMMENT ON COLUMN inventory.monthly_stock_snapshots.location_id IS '위치';
COMMENT ON COLUMN inventory.monthly_stock_snapshots.stock_condition IS '재고 상태';
COMMENT ON COLUMN inventory.monthly_stock_snapshots.owner_type IS '소유 구분(자사/타사)';
COMMENT ON COLUMN inventory.monthly_stock_snapshots.owner_partner_id IS '타사 소유 업체';
COMMENT ON COLUMN inventory.monthly_stock_snapshots.quantity IS '수량';
COMMENT ON TABLE inventory.stock_counts IS '재고 실사';
COMMENT ON COLUMN inventory.stock_counts.id IS 'ID (UUID v7, 앱에서 생성. DB 기본값도 v7, PostgreSQL 18)';
COMMENT ON COLUMN inventory.stock_counts.count_no IS '실사 번호';
COMMENT ON COLUMN inventory.stock_counts.scope_type IS '범위 유형';
COMMENT ON COLUMN inventory.stock_counts.base_date IS '실사 기준일';
COMMENT ON COLUMN inventory.stock_counts.assignee_id IS '담당자';
COMMENT ON COLUMN inventory.stock_counts.status IS '상태';
COMMENT ON COLUMN inventory.stock_counts.started_at IS '시작 시각';
COMMENT ON COLUMN inventory.stock_counts.approved_by IS '승인자';
COMMENT ON COLUMN inventory.stock_counts.approved_at IS '승인 시각';
COMMENT ON COLUMN inventory.stock_counts.adjustment_transaction_id IS '실사 조정 묶음';
COMMENT ON COLUMN inventory.stock_counts.note IS '비고';
COMMENT ON COLUMN inventory.stock_counts.created_at IS '생성 시각';
COMMENT ON COLUMN inventory.stock_counts.created_by IS '생성자';
COMMENT ON COLUMN inventory.stock_counts.updated_at IS '수정 시각';
COMMENT ON COLUMN inventory.stock_counts.updated_by IS '수정자';
COMMENT ON COLUMN inventory.stock_counts.version IS '버전(낙관적 잠금)';
COMMENT ON TABLE inventory.stock_count_scopes IS '실사 잠금 범위';
COMMENT ON COLUMN inventory.stock_count_scopes.id IS 'ID (UUID v7, 앱에서 생성. DB 기본값도 v7, PostgreSQL 18)';
COMMENT ON COLUMN inventory.stock_count_scopes.count_id IS '실사';
COMMENT ON COLUMN inventory.stock_count_scopes.location_id IS '위치';
COMMENT ON COLUMN inventory.stock_count_scopes.product_id IS '제품';
COMMENT ON TABLE inventory.stock_count_lines IS '실사 품목';
COMMENT ON COLUMN inventory.stock_count_lines.id IS 'ID (UUID v7, 앱에서 생성. DB 기본값도 v7, PostgreSQL 18)';
COMMENT ON COLUMN inventory.stock_count_lines.count_id IS '실사';
COMMENT ON COLUMN inventory.stock_count_lines.product_id IS '제품';
COMMENT ON COLUMN inventory.stock_count_lines.location_id IS '위치';
COMMENT ON COLUMN inventory.stock_count_lines.stock_condition IS '재고 상태';
COMMENT ON COLUMN inventory.stock_count_lines.owner_type IS '소유 구분(자사/타사)';
COMMENT ON COLUMN inventory.stock_count_lines.owner_partner_id IS '타사 소유 업체';
COMMENT ON COLUMN inventory.stock_count_lines.book_quantity IS '장부 수량(시작 시점)';
COMMENT ON COLUMN inventory.stock_count_lines.counted_quantity IS '실물 수량';
COMMENT ON COLUMN inventory.stock_count_lines.recounted IS '재실사 여부';
COMMENT ON COLUMN inventory.stock_count_lines.note IS '비고';
COMMENT ON TABLE inventory.stock_count_serials IS '실사 시리얼 대조';
COMMENT ON COLUMN inventory.stock_count_serials.id IS 'ID (UUID v7, 앱에서 생성. DB 기본값도 v7, PostgreSQL 18)';
COMMENT ON COLUMN inventory.stock_count_serials.count_id IS '실사';
COMMENT ON COLUMN inventory.stock_count_serials.line_id IS '실사 품목';
COMMENT ON COLUMN inventory.stock_count_serials.serial_no IS '시리얼';
COMMENT ON COLUMN inventory.stock_count_serials.equipment_id IS '장비';
COMMENT ON COLUMN inventory.stock_count_serials.result IS '대조 결과';
COMMENT ON TABLE equipment.equipment IS '개별 장비(시리얼)';
COMMENT ON COLUMN equipment.equipment.id IS 'ID (UUID v7, 앱에서 생성. DB 기본값도 v7, PostgreSQL 18)';
COMMENT ON COLUMN equipment.equipment.product_id IS '제품';
COMMENT ON COLUMN equipment.equipment.serial_no IS '시리얼 번호(미확인 시 NULL)';
COMMENT ON COLUMN equipment.equipment.serial_status IS '시리얼 확인 상태';
COMMENT ON COLUMN equipment.equipment.status IS '장비 상태';
COMMENT ON COLUMN equipment.equipment.current_location_id IS '현재 위치';
COMMENT ON COLUMN equipment.equipment.owner_type IS '소유 구분(자사/타사)';
COMMENT ON COLUMN equipment.equipment.owner_partner_id IS '타사 소유 업체';
COMMENT ON COLUMN equipment.equipment.project_id IS '프로젝트';
COMMENT ON COLUMN equipment.equipment.delivered_partner_id IS '납품처';
COMMENT ON COLUMN equipment.equipment.replaced_by_equipment_id IS '교체된 새 장비';
COMMENT ON COLUMN equipment.equipment.origin_type IS '생성 경로(원장/기준일 이전 납품)';
COMMENT ON COLUMN equipment.equipment.last_event_date IS '마지막 처리 날짜';
COMMENT ON COLUMN equipment.equipment.created_at IS '생성 시각';
COMMENT ON COLUMN equipment.equipment.created_by IS '생성자';
COMMENT ON COLUMN equipment.equipment.updated_at IS '수정 시각';
COMMENT ON COLUMN equipment.equipment.updated_by IS '수정자';
COMMENT ON COLUMN equipment.equipment.version IS '버전(낙관적 잠금)';
COMMENT ON TABLE equipment.equipment_events IS '장비 이력';
COMMENT ON COLUMN equipment.equipment_events.id IS 'ID (UUID v7, 앱에서 생성. DB 기본값도 v7, PostgreSQL 18)';
COMMENT ON COLUMN equipment.equipment_events.equipment_id IS '장비';
COMMENT ON COLUMN equipment.equipment_events.event_type IS '이벤트 유형';
COMMENT ON COLUMN equipment.equipment_events.business_date IS '업무 날짜';
COMMENT ON COLUMN equipment.equipment_events.from_status IS '이전 상태';
COMMENT ON COLUMN equipment.equipment_events.to_status IS '이후 상태';
COMMENT ON COLUMN equipment.equipment_events.from_location_id IS '출발 위치';
COMMENT ON COLUMN equipment.equipment_events.to_location_id IS '도착 위치';
COMMENT ON COLUMN equipment.equipment_events.old_value IS '이전 값(시리얼 수정 등)';
COMMENT ON COLUMN equipment.equipment_events.new_value IS '새 값(시리얼 수정 등)';
COMMENT ON COLUMN equipment.equipment_events.ledger_entry_id IS '원장 행';
COMMENT ON COLUMN equipment.equipment_events.source_type IS '출처 유형';
COMMENT ON COLUMN equipment.equipment_events.source_id IS '출처 ID';
COMMENT ON COLUMN equipment.equipment_events.note IS '비고';
COMMENT ON COLUMN equipment.equipment_events.created_at IS '생성 시각';
COMMENT ON COLUMN equipment.equipment_events.created_by IS '생성자';
COMMENT ON TABLE equipment.warranties IS '보증';
COMMENT ON COLUMN equipment.warranties.id IS 'ID (UUID v7, 앱에서 생성. DB 기본값도 v7, PostgreSQL 18)';
COMMENT ON COLUMN equipment.warranties.equipment_id IS '장비';
COMMENT ON COLUMN equipment.warranties.status IS '확인 상태';
COMMENT ON COLUMN equipment.warranties.start_date IS '보증 시작일';
COMMENT ON COLUMN equipment.warranties.end_date IS '보증 만료일';
COMMENT ON COLUMN equipment.warranties.basis IS '시작 기준';
COMMENT ON COLUMN equipment.warranties.inherited_from_equipment_id IS '승계 원 장비';
COMMENT ON COLUMN equipment.warranties.note IS '비고';
COMMENT ON COLUMN equipment.warranties.created_at IS '생성 시각';
COMMENT ON COLUMN equipment.warranties.created_by IS '생성자';
COMMENT ON COLUMN equipment.warranties.updated_at IS '수정 시각';
COMMENT ON COLUMN equipment.warranties.updated_by IS '수정자';
COMMENT ON COLUMN equipment.warranties.version IS '버전(낙관적 잠금)';
COMMENT ON TABLE equipment.warranty_changes IS '보증 변경 이력';
COMMENT ON COLUMN equipment.warranty_changes.id IS 'ID (UUID v7, 앱에서 생성. DB 기본값도 v7, PostgreSQL 18)';
COMMENT ON COLUMN equipment.warranty_changes.warranty_id IS '보증';
COMMENT ON COLUMN equipment.warranty_changes.old_start_date IS '이전 시작일';
COMMENT ON COLUMN equipment.warranty_changes.old_end_date IS '이전 만료일';
COMMENT ON COLUMN equipment.warranty_changes.new_start_date IS '변경 시작일';
COMMENT ON COLUMN equipment.warranty_changes.new_end_date IS '변경 만료일';
COMMENT ON COLUMN equipment.warranty_changes.reason IS '사유';
COMMENT ON COLUMN equipment.warranty_changes.changed_by IS '변경자';
COMMENT ON COLUMN equipment.warranty_changes.changed_at IS '변경 시각';
COMMENT ON TABLE project.projects IS '프로젝트';
COMMENT ON COLUMN project.projects.id IS 'ID (UUID v7, 앱에서 생성. DB 기본값도 v7, PostgreSQL 18)';
COMMENT ON COLUMN project.projects.project_code IS '프로젝트 코드';
COMMENT ON COLUMN project.projects.project_name IS '프로젝트명';
COMMENT ON COLUMN project.projects.customer_partner_id IS '주 고객사';
COMMENT ON COLUMN project.projects.status IS '상태';
COMMENT ON COLUMN project.projects.note IS '비고';
COMMENT ON COLUMN project.projects.created_at IS '생성 시각';
COMMENT ON COLUMN project.projects.created_by IS '생성자';
COMMENT ON COLUMN project.projects.updated_at IS '수정 시각';
COMMENT ON COLUMN project.projects.updated_by IS '수정자';
COMMENT ON COLUMN project.projects.version IS '버전(낙관적 잠금)';
COMMENT ON COLUMN project.projects.deleted_at IS '삭제 시각';
COMMENT ON COLUMN project.projects.deleted_by IS '삭제자';
COMMENT ON TABLE project.trade_documents IS '거래 문서(발주서·매출·선발주)';
COMMENT ON COLUMN project.trade_documents.id IS 'ID (UUID v7, 앱에서 생성. DB 기본값도 v7, PostgreSQL 18)';
COMMENT ON COLUMN project.trade_documents.project_id IS '프로젝트';
COMMENT ON COLUMN project.trade_documents.trade_type IS '거래 구분';
COMMENT ON COLUMN project.trade_documents.partner_id IS '거래처';
COMMENT ON COLUMN project.trade_documents.document_no IS '거래처 문서번호';
COMMENT ON COLUMN project.trade_documents.document_date IS '문서 일자';
COMMENT ON COLUMN project.trade_documents.status IS '상태';
COMMENT ON COLUMN project.trade_documents.copied_from_document_id IS '복사 원본 문서';
COMMENT ON COLUMN project.trade_documents.note IS '비고';
COMMENT ON COLUMN project.trade_documents.created_at IS '생성 시각';
COMMENT ON COLUMN project.trade_documents.created_by IS '생성자';
COMMENT ON COLUMN project.trade_documents.updated_at IS '수정 시각';
COMMENT ON COLUMN project.trade_documents.updated_by IS '수정자';
COMMENT ON COLUMN project.trade_documents.version IS '버전(낙관적 잠금)';
COMMENT ON COLUMN project.trade_documents.deleted_at IS '삭제 시각';
COMMENT ON COLUMN project.trade_documents.deleted_by IS '삭제자';
COMMENT ON TABLE project.trade_lines IS '거래 품목';
COMMENT ON COLUMN project.trade_lines.id IS 'ID (UUID v7, 앱에서 생성. DB 기본값도 v7, PostgreSQL 18)';
COMMENT ON COLUMN project.trade_lines.document_id IS '거래 문서';
COMMENT ON COLUMN project.trade_lines.line_no IS '행 번호';
COMMENT ON COLUMN project.trade_lines.product_id IS '제품';
COMMENT ON COLUMN project.trade_lines.quantity IS '문서 수량';
COMMENT ON COLUMN project.trade_lines.opening_fulfilled_quantity IS '기준일 이전 처리 수량';
COMMENT ON COLUMN project.trade_lines.fulfilled_quantity IS '처리된 수량';
COMMENT ON COLUMN project.trade_lines.closed_quantity IS '잔량 마감 수량';
COMMENT ON COLUMN project.trade_lines.closed_reason IS '잔량 마감 사유';
COMMENT ON COLUMN project.trade_lines.closed_by IS '잔량 마감자';
COMMENT ON COLUMN project.trade_lines.closed_at IS '잔량 마감 시각';
COMMENT ON COLUMN project.trade_lines.route IS '경로(창고 경유/직납)';
COMMENT ON COLUMN project.trade_lines.note IS '비고';
COMMENT ON COLUMN project.trade_lines.created_at IS '생성 시각';
COMMENT ON COLUMN project.trade_lines.created_by IS '생성자';
COMMENT ON COLUMN project.trade_lines.updated_at IS '수정 시각';
COMMENT ON COLUMN project.trade_lines.updated_by IS '수정자';
COMMENT ON COLUMN project.trade_lines.version IS '버전(낙관적 잠금)';
COMMENT ON TABLE project.trade_document_changes IS '거래 문서 변경 이력';
COMMENT ON COLUMN project.trade_document_changes.id IS 'ID (UUID v7, 앱에서 생성. DB 기본값도 v7, PostgreSQL 18)';
COMMENT ON COLUMN project.trade_document_changes.document_id IS '거래 문서';
COMMENT ON COLUMN project.trade_document_changes.line_id IS '거래 품목';
COMMENT ON COLUMN project.trade_document_changes.field_name IS '변경 항목';
COMMENT ON COLUMN project.trade_document_changes.old_value IS '이전 값';
COMMENT ON COLUMN project.trade_document_changes.new_value IS '새 값';
COMMENT ON COLUMN project.trade_document_changes.reason IS '사유';
COMMENT ON COLUMN project.trade_document_changes.changed_by IS '변경자';
COMMENT ON COLUMN project.trade_document_changes.changed_at IS '변경 시각';
COMMENT ON TABLE allocation.allocations IS '배정';
COMMENT ON COLUMN allocation.allocations.id IS 'ID (UUID v7, 앱에서 생성. DB 기본값도 v7, PostgreSQL 18)';
COMMENT ON COLUMN allocation.allocations.product_id IS '제품';
COMMENT ON COLUMN allocation.allocations.quantity IS '배정 수량';
COMMENT ON COLUMN allocation.allocations.consumed_quantity IS '소진 수량';
COMMENT ON COLUMN allocation.allocations.target_type IS '배정 대상 유형';
COMMENT ON COLUMN allocation.allocations.project_id IS '대상 프로젝트';
COMMENT ON COLUMN allocation.allocations.loan_document_id IS '대상 차입(상환용)';
COMMENT ON COLUMN allocation.allocations.source_type IS '배정 원천(보유/예정)';
COMMENT ON COLUMN allocation.allocations.source_trade_line_id IS '예정 물량 발주 품목';
COMMENT ON COLUMN allocation.allocations.owner_type IS '보유 재고 소유 구분';
COMMENT ON COLUMN allocation.allocations.owner_partner_id IS '타사 소유 업체';
COMMENT ON COLUMN allocation.allocations.equipment_id IS '개별 장비';
COMMENT ON COLUMN allocation.allocations.status IS '상태';
COMMENT ON COLUMN allocation.allocations.note IS '비고';
COMMENT ON COLUMN allocation.allocations.created_at IS '생성 시각';
COMMENT ON COLUMN allocation.allocations.created_by IS '생성자';
COMMENT ON COLUMN allocation.allocations.updated_at IS '수정 시각';
COMMENT ON COLUMN allocation.allocations.updated_by IS '수정자';
COMMENT ON COLUMN allocation.allocations.version IS '버전(낙관적 잠금)';
COMMENT ON TABLE allocation.allocation_events IS '배정 이력';
COMMENT ON COLUMN allocation.allocation_events.id IS 'ID (UUID v7, 앱에서 생성. DB 기본값도 v7, PostgreSQL 18)';
COMMENT ON COLUMN allocation.allocation_events.allocation_id IS '배정';
COMMENT ON COLUMN allocation.allocation_events.action IS '동작';
COMMENT ON COLUMN allocation.allocation_events.quantity IS '수량';
COMMENT ON COLUMN allocation.allocation_events.reason IS '사유';
COMMENT ON COLUMN allocation.allocation_events.acted_by IS '처리자';
COMMENT ON COLUMN allocation.allocation_events.acted_at IS '처리 시각';
COMMENT ON TABLE delivery.deliveries IS '납품 회차';
COMMENT ON COLUMN delivery.deliveries.id IS 'ID (UUID v7, 앱에서 생성. DB 기본값도 v7, PostgreSQL 18)';
COMMENT ON COLUMN delivery.deliveries.delivery_no IS '납품 번호';
COMMENT ON COLUMN delivery.deliveries.project_id IS '프로젝트';
COMMENT ON COLUMN delivery.deliveries.sales_document_id IS '매출 문서';
COMMENT ON COLUMN delivery.deliveries.customer_partner_id IS '고객사';
COMMENT ON COLUMN delivery.deliveries.delivery_date IS '납품일';
COMMENT ON COLUMN delivery.deliveries.place IS '납품 장소';
COMMENT ON COLUMN delivery.deliveries.route IS '경로(창고 경유/직납)';
COMMENT ON COLUMN delivery.deliveries.bundle_id IS '구성 묶음';
COMMENT ON COLUMN delivery.deliveries.bundle_set_quantity IS '세트 수';
COMMENT ON COLUMN delivery.deliveries.status IS '상태';
COMMENT ON COLUMN delivery.deliveries.transaction_id IS '창고 출고 묶음';
COMMENT ON COLUMN delivery.deliveries.note IS '비고';
COMMENT ON COLUMN delivery.deliveries.created_at IS '생성 시각';
COMMENT ON COLUMN delivery.deliveries.created_by IS '생성자';
COMMENT ON COLUMN delivery.deliveries.updated_at IS '수정 시각';
COMMENT ON COLUMN delivery.deliveries.updated_by IS '수정자';
COMMENT ON COLUMN delivery.deliveries.version IS '버전(낙관적 잠금)';
COMMENT ON TABLE delivery.delivery_lines IS '납품 품목';
COMMENT ON COLUMN delivery.delivery_lines.id IS 'ID (UUID v7, 앱에서 생성. DB 기본값도 v7, PostgreSQL 18)';
COMMENT ON COLUMN delivery.delivery_lines.delivery_id IS '납품 회차';
COMMENT ON COLUMN delivery.delivery_lines.line_no IS '행 번호';
COMMENT ON COLUMN delivery.delivery_lines.product_id IS '제품';
COMMENT ON COLUMN delivery.delivery_lines.quantity IS '납품 수량';
COMMENT ON COLUMN delivery.delivery_lines.sales_line_id IS '매출 품목';
COMMENT ON COLUMN delivery.delivery_lines.purchase_line_id IS '직납 발주 품목';
COMMENT ON COLUMN delivery.delivery_lines.loan_line_id IS '차입 직납 대차 품목';
COMMENT ON COLUMN delivery.delivery_lines.equipment_id IS '개별 장비';
COMMENT ON COLUMN delivery.delivery_lines.returned_quantity IS '반품 수량';
COMMENT ON COLUMN delivery.delivery_lines.note IS '비고';
COMMENT ON TABLE delivery.delivery_returns IS '고객 반품';
COMMENT ON COLUMN delivery.delivery_returns.id IS 'ID (UUID v7, 앱에서 생성. DB 기본값도 v7, PostgreSQL 18)';
COMMENT ON COLUMN delivery.delivery_returns.delivery_line_id IS '납품 품목';
COMMENT ON COLUMN delivery.delivery_returns.equipment_id IS '기준일 이전 납품 장비';
COMMENT ON COLUMN delivery.delivery_returns.quantity IS '반품 수량';
COMMENT ON COLUMN delivery.delivery_returns.return_date IS '반품일';
COMMENT ON COLUMN delivery.delivery_returns.transaction_id IS '반품 입고 묶음';
COMMENT ON COLUMN delivery.delivery_returns.reason IS '사유';
COMMENT ON COLUMN delivery.delivery_returns.created_at IS '생성 시각';
COMMENT ON COLUMN delivery.delivery_returns.created_by IS '생성자';
COMMENT ON COLUMN delivery.delivery_returns.updated_at IS '수정 시각';
COMMENT ON COLUMN delivery.delivery_returns.updated_by IS '수정자';
COMMENT ON COLUMN delivery.delivery_returns.version IS '버전(낙관적 잠금)';
COMMENT ON TABLE loan.loan_documents IS '대차 문서(차입·대여)';
COMMENT ON COLUMN loan.loan_documents.id IS 'ID (UUID v7, 앱에서 생성. DB 기본값도 v7, PostgreSQL 18)';
COMMENT ON COLUMN loan.loan_documents.loan_no IS '대차 번호';
COMMENT ON COLUMN loan.loan_documents.direction IS '방향(차입/대여)';
COMMENT ON COLUMN loan.loan_documents.partner_id IS '상대 업체';
COMMENT ON COLUMN loan.loan_documents.project_id IS '관련 프로젝트';
COMMENT ON COLUMN loan.loan_documents.settlement_method IS '정산 방식';
COMMENT ON COLUMN loan.loan_documents.due_date IS '상환·회수 기한';
COMMENT ON COLUMN loan.loan_documents.status IS '상태';
COMMENT ON COLUMN loan.loan_documents.converted_trade_document_id IS '전환 거래 문서';
COMMENT ON COLUMN loan.loan_documents.approved_by IS '승인자';
COMMENT ON COLUMN loan.loan_documents.approved_at IS '승인 시각';
COMMENT ON COLUMN loan.loan_documents.note IS '비고';
COMMENT ON COLUMN loan.loan_documents.created_at IS '생성 시각';
COMMENT ON COLUMN loan.loan_documents.created_by IS '생성자';
COMMENT ON COLUMN loan.loan_documents.updated_at IS '수정 시각';
COMMENT ON COLUMN loan.loan_documents.updated_by IS '수정자';
COMMENT ON COLUMN loan.loan_documents.version IS '버전(낙관적 잠금)';
COMMENT ON COLUMN loan.loan_documents.deleted_at IS '삭제 시각';
COMMENT ON COLUMN loan.loan_documents.deleted_by IS '삭제자';
COMMENT ON TABLE loan.loan_lines IS '대차 품목';
COMMENT ON COLUMN loan.loan_lines.id IS 'ID (UUID v7, 앱에서 생성. DB 기본값도 v7, PostgreSQL 18)';
COMMENT ON COLUMN loan.loan_lines.loan_id IS '대차 문서';
COMMENT ON COLUMN loan.loan_lines.line_no IS '행 번호';
COMMENT ON COLUMN loan.loan_lines.product_id IS '제품';
COMMENT ON COLUMN loan.loan_lines.quantity IS '수량';
COMMENT ON COLUMN loan.loan_lines.moved_quantity IS '받은(차입)·내보낸(대여) 수량';
COMMENT ON COLUMN loan.loan_lines.settled_quantity IS '정산 수량';
COMMENT ON COLUMN loan.loan_lines.equipment_id IS '개별 장비';
COMMENT ON COLUMN loan.loan_lines.note IS '비고';
COMMENT ON TABLE loan.loan_settlements IS '대차 정산 기록';
COMMENT ON COLUMN loan.loan_settlements.id IS 'ID (UUID v7, 앱에서 생성. DB 기본값도 v7, PostgreSQL 18)';
COMMENT ON COLUMN loan.loan_settlements.loan_line_id IS '대차 품목';
COMMENT ON COLUMN loan.loan_settlements.settled_date IS '정산 날짜';
COMMENT ON COLUMN loan.loan_settlements.method IS '정산 방식';
COMMENT ON COLUMN loan.loan_settlements.quantity IS '정산 수량';
COMMENT ON COLUMN loan.loan_settlements.settled_product_id IS '실제 주고받은 제품';
COMMENT ON COLUMN loan.loan_settlements.equipment_id IS '개별 장비';
COMMENT ON COLUMN loan.loan_settlements.status IS '상태';
COMMENT ON COLUMN loan.loan_settlements.transaction_id IS '처리 묶음';
COMMENT ON COLUMN loan.loan_settlements.trade_document_id IS '전환 거래 문서';
COMMENT ON COLUMN loan.loan_settlements.note IS '비고';
COMMENT ON COLUMN loan.loan_settlements.created_at IS '생성 시각';
COMMENT ON COLUMN loan.loan_settlements.created_by IS '생성자';
COMMENT ON COLUMN loan.loan_settlements.updated_at IS '수정 시각';
COMMENT ON COLUMN loan.loan_settlements.updated_by IS '수정자';
COMMENT ON COLUMN loan.loan_settlements.version IS '버전(낙관적 잠금)';
COMMENT ON TABLE loan.loan_document_changes IS '대차 문서 변경 이력';
COMMENT ON COLUMN loan.loan_document_changes.id IS 'ID (UUID v7, 앱에서 생성. DB 기본값도 v7, PostgreSQL 18)';
COMMENT ON COLUMN loan.loan_document_changes.loan_id IS '대차 문서';
COMMENT ON COLUMN loan.loan_document_changes.line_id IS '대차 품목';
COMMENT ON COLUMN loan.loan_document_changes.field_name IS '변경 항목';
COMMENT ON COLUMN loan.loan_document_changes.old_value IS '이전 값';
COMMENT ON COLUMN loan.loan_document_changes.new_value IS '새 값';
COMMENT ON COLUMN loan.loan_document_changes.reason IS '사유';
COMMENT ON COLUMN loan.loan_document_changes.changed_by IS '변경자';
COMMENT ON COLUMN loan.loan_document_changes.changed_at IS '변경 시각';
COMMENT ON TABLE trash.trash_events IS '삭제·복구 이력';
COMMENT ON COLUMN trash.trash_events.id IS 'ID (UUID v7, 앱에서 생성. DB 기본값도 v7, PostgreSQL 18)';
COMMENT ON COLUMN trash.trash_events.entity_type IS '대상 유형';
COMMENT ON COLUMN trash.trash_events.entity_id IS '대상 ID';
COMMENT ON COLUMN trash.trash_events.action IS '동작(삭제/복구)';
COMMENT ON COLUMN trash.trash_events.reason IS '사유';
COMMENT ON COLUMN trash.trash_events.acted_by IS '처리자';
COMMENT ON COLUMN trash.trash_events.acted_at IS '처리 시각';
COMMENT ON TABLE cost.currencies IS '통화';
COMMENT ON COLUMN cost.currencies.code IS '통화 코드(ISO 4217)';
COMMENT ON COLUMN cost.currencies.name IS '통화명';
COMMENT ON COLUMN cost.currencies.minor_unit IS '소수 자리수';
COMMENT ON COLUMN cost.currencies.is_active IS '사용 여부';
COMMENT ON TABLE cost.line_prices IS '거래 품목 단가';
COMMENT ON COLUMN cost.line_prices.trade_line_id IS '거래 품목';
COMMENT ON COLUMN cost.line_prices.unit_price IS '단가';
COMMENT ON COLUMN cost.line_prices.currency IS '통화';
COMMENT ON COLUMN cost.line_prices.exchange_rate IS '적용 환율';
COMMENT ON COLUMN cost.line_prices.exchange_rate_date IS '환율 기준일';
COMMENT ON COLUMN cost.line_prices.unit_price_krw IS '원화 환산';
COMMENT ON COLUMN cost.line_prices.tax_type IS '과세 구분';
COMMENT ON COLUMN cost.line_prices.attribution_basis IS '금액 귀속 기준';
COMMENT ON COLUMN cost.line_prices.attribution_date IS '직접 입력한 귀속일(MANUAL일 때)';
COMMENT ON COLUMN cost.line_prices.created_at IS '생성 시각';
COMMENT ON COLUMN cost.line_prices.created_by IS '생성자';
COMMENT ON COLUMN cost.line_prices.updated_at IS '수정 시각';
COMMENT ON COLUMN cost.line_prices.updated_by IS '수정자';
COMMENT ON COLUMN cost.line_prices.version IS '버전(낙관적 잠금)';
COMMENT ON TABLE cost.extra_costs IS '부대비용';
COMMENT ON COLUMN cost.extra_costs.id IS 'ID (UUID v7, 앱에서 생성. DB 기본값도 v7, PostgreSQL 18)';
COMMENT ON COLUMN cost.extra_costs.project_id IS '프로젝트';
COMMENT ON COLUMN cost.extra_costs.cost_type IS '비용 유형';
COMMENT ON COLUMN cost.extra_costs.amount IS '금액';
COMMENT ON COLUMN cost.extra_costs.currency IS '통화';
COMMENT ON COLUMN cost.extra_costs.exchange_rate IS '적용 환율';
COMMENT ON COLUMN cost.extra_costs.exchange_rate_date IS '환율 기준일';
COMMENT ON COLUMN cost.extra_costs.amount_krw IS '원화 환산';
COMMENT ON COLUMN cost.extra_costs.cost_date IS '비용 발생일';
COMMENT ON COLUMN cost.extra_costs.trade_document_id IS '관련 거래 문서';
COMMENT ON COLUMN cost.extra_costs.loan_document_id IS '관련 대차 문서';
COMMENT ON COLUMN cost.extra_costs.note IS '비고';
COMMENT ON COLUMN cost.extra_costs.attribution_basis IS '금액 귀속 기준';
COMMENT ON COLUMN cost.extra_costs.attribution_date IS '직접 입력한 귀속일(MANUAL일 때)';
COMMENT ON COLUMN cost.extra_costs.created_at IS '생성 시각';
COMMENT ON COLUMN cost.extra_costs.created_by IS '생성자';
COMMENT ON COLUMN cost.extra_costs.updated_at IS '수정 시각';
COMMENT ON COLUMN cost.extra_costs.updated_by IS '수정자';
COMMENT ON COLUMN cost.extra_costs.version IS '버전(낙관적 잠금)';
COMMENT ON COLUMN cost.extra_costs.deleted_at IS '삭제 시각';
COMMENT ON COLUMN cost.extra_costs.deleted_by IS '삭제자';
COMMENT ON TABLE cost.loan_fees IS '대여료';
COMMENT ON COLUMN cost.loan_fees.loan_document_id IS '대차 문서';
COMMENT ON COLUMN cost.loan_fees.amount IS '금액';
COMMENT ON COLUMN cost.loan_fees.currency IS '통화';
COMMENT ON COLUMN cost.loan_fees.exchange_rate IS '적용 환율';
COMMENT ON COLUMN cost.loan_fees.exchange_rate_date IS '환율 기준일';
COMMENT ON COLUMN cost.loan_fees.amount_krw IS '원화 환산';
COMMENT ON COLUMN cost.loan_fees.attribution_basis IS '금액 귀속 기준';
COMMENT ON COLUMN cost.loan_fees.attribution_date IS '직접 입력한 귀속일(MANUAL일 때)';
COMMENT ON COLUMN cost.loan_fees.created_at IS '생성 시각';
COMMENT ON COLUMN cost.loan_fees.created_by IS '생성자';
COMMENT ON COLUMN cost.loan_fees.updated_at IS '수정 시각';
COMMENT ON COLUMN cost.loan_fees.updated_by IS '수정자';
COMMENT ON COLUMN cost.loan_fees.version IS '버전(낙관적 잠금)';
COMMENT ON TABLE cost.opening_costs IS '초기 재고 단가';
COMMENT ON COLUMN cost.opening_costs.ledger_entry_id IS '초기 재고 원장 행';
COMMENT ON COLUMN cost.opening_costs.unit_cost IS '단가';
COMMENT ON COLUMN cost.opening_costs.currency IS '통화';
COMMENT ON COLUMN cost.opening_costs.exchange_rate IS '적용 환율';
COMMENT ON COLUMN cost.opening_costs.exchange_rate_date IS '환율 기준일';
COMMENT ON COLUMN cost.opening_costs.unit_cost_krw IS '원화 환산';
COMMENT ON COLUMN cost.opening_costs.note IS '평가 근거';
COMMENT ON COLUMN cost.opening_costs.attribution_basis IS '금액 귀속 기준';
COMMENT ON COLUMN cost.opening_costs.attribution_date IS '직접 입력한 귀속일(MANUAL일 때)';
COMMENT ON COLUMN cost.opening_costs.created_at IS '생성 시각';
COMMENT ON COLUMN cost.opening_costs.created_by IS '생성자';
COMMENT ON COLUMN cost.opening_costs.updated_at IS '수정 시각';
COMMENT ON COLUMN cost.opening_costs.updated_by IS '수정자';
COMMENT ON COLUMN cost.opening_costs.version IS '버전(낙관적 잠금)';
COMMENT ON TABLE cost.cost_changes IS '금액 변경 이력';
COMMENT ON COLUMN cost.cost_changes.id IS 'ID (UUID v7, 앱에서 생성. DB 기본값도 v7, PostgreSQL 18)';
COMMENT ON COLUMN cost.cost_changes.target_type IS '대상 유형';
COMMENT ON COLUMN cost.cost_changes.target_id IS '대상 ID(거래 품목·부대비용·대차 문서·원장 행)';
COMMENT ON COLUMN cost.cost_changes.field_name IS '바뀐 항목';
COMMENT ON COLUMN cost.cost_changes.old_value IS '이전 값';
COMMENT ON COLUMN cost.cost_changes.new_value IS '새 값';
COMMENT ON COLUMN cost.cost_changes.reason IS '사유';
COMMENT ON COLUMN cost.cost_changes.changed_by IS '변경자';
COMMENT ON COLUMN cost.cost_changes.changed_at IS '변경 시각';
COMMENT ON TABLE importing.files IS '첨부 파일(증빙)';
COMMENT ON COLUMN importing.files.id IS 'ID (UUID v7, 앱에서 생성. DB 기본값도 v7, PostgreSQL 18)';
COMMENT ON COLUMN importing.files.target_type IS '첨부 대상 종류';
COMMENT ON COLUMN importing.files.target_id IS '첨부 대상 ID';
COMMENT ON COLUMN importing.files.original_name IS '원본 파일명';
COMMENT ON COLUMN importing.files.content_type IS '파일 형식(MIME)';
COMMENT ON COLUMN importing.files.storage_key IS '저장 위치 키(최상위 폴더 기준 상대 경로)';
COMMENT ON COLUMN importing.files.content_hash IS '내용 해시(SHA-256, 같은 내용 경고용)';
COMMENT ON COLUMN importing.files.size_bytes IS '크기(바이트)';
COMMENT ON COLUMN importing.files.uploaded_by IS '올린 사람';
COMMENT ON COLUMN importing.files.uploaded_at IS '올린 시각';
COMMENT ON COLUMN importing.files.note IS '비고';
COMMENT ON COLUMN importing.files.deleted_at IS '삭제 시각';
COMMENT ON COLUMN importing.files.deleted_by IS '삭제자';
COMMENT ON TABLE common.idempotency_keys IS '중복 요청 키';
COMMENT ON COLUMN common.idempotency_keys.idempotency_key IS '중복 요청 키';
COMMENT ON COLUMN common.idempotency_keys.user_id IS '요청자';
COMMENT ON COLUMN common.idempotency_keys.action IS 'API 동작';
COMMENT ON COLUMN common.idempotency_keys.request_hash IS '요청 내용 해시';
COMMENT ON COLUMN common.idempotency_keys.status IS '처리 상태';
COMMENT ON COLUMN common.idempotency_keys.response_status IS '처음 응답 HTTP 상태';
COMMENT ON COLUMN common.idempotency_keys.response_body IS '처음 응답 본문';
COMMENT ON COLUMN common.idempotency_keys.created_at IS '받은 시각';
COMMENT ON COLUMN common.idempotency_keys.completed_at IS '끝난 시각';
COMMENT ON TABLE admin.review_requests IS '승인·확인 요청';
COMMENT ON COLUMN admin.review_requests.id IS 'ID (UUID v7, 앱에서 생성. DB 기본값도 v7, PostgreSQL 18)';
COMMENT ON COLUMN admin.review_requests.request_type IS '요청 종류';
COMMENT ON COLUMN admin.review_requests.target_type IS '대상 유형';
COMMENT ON COLUMN admin.review_requests.target_id IS '대상 ID';
COMMENT ON COLUMN admin.review_requests.status IS '상태';
COMMENT ON COLUMN admin.review_requests.summary IS '요약';
COMMENT ON COLUMN admin.review_requests.requested_by IS '요청자';
COMMENT ON COLUMN admin.review_requests.requested_at IS '요청 시각';
COMMENT ON COLUMN admin.review_requests.decided_by IS '처리자';
COMMENT ON COLUMN admin.review_requests.decided_at IS '처리 시각';
COMMENT ON COLUMN admin.review_requests.decision_reason IS '반려 사유';
COMMENT ON COLUMN admin.review_requests.version IS '버전(낙관적 잠금)';
COMMENT ON TABLE admin.notifications IS '알림';
COMMENT ON COLUMN admin.notifications.id IS 'ID (UUID v7, 앱에서 생성. DB 기본값도 v7, PostgreSQL 18)';
COMMENT ON COLUMN admin.notifications.recipient_user_id IS '받는 사람';
COMMENT ON COLUMN admin.notifications.notification_type IS '알림 종류';
COMMENT ON COLUMN admin.notifications.title IS '제목';
COMMENT ON COLUMN admin.notifications.message IS '내용';
COMMENT ON COLUMN admin.notifications.target_type IS '연결 대상 유형';
COMMENT ON COLUMN admin.notifications.target_id IS '연결 대상 ID';
COMMENT ON COLUMN admin.notifications.created_at IS '생성 시각';
COMMENT ON COLUMN admin.notifications.read_at IS '읽은 시각';
COMMENT ON TABLE admin.integrity_check_results IS '정합성 점검 결과';
COMMENT ON COLUMN admin.integrity_check_results.id IS 'ID (UUID v7, 앱에서 생성. DB 기본값도 v7, PostgreSQL 18)';
COMMENT ON COLUMN admin.integrity_check_results.check_code IS '점검 항목(C1~)';
COMMENT ON COLUMN admin.integrity_check_results.target_type IS '어긋난 대상 유형';
COMMENT ON COLUMN admin.integrity_check_results.target_key IS '어긋난 대상 키';
COMMENT ON COLUMN admin.integrity_check_results.detail IS '어긋난 내용';
COMMENT ON COLUMN admin.integrity_check_results.first_found_at IS '처음 발견 시각';
COMMENT ON COLUMN admin.integrity_check_results.last_found_at IS '마지막 발견 시각';
COMMENT ON COLUMN admin.integrity_check_results.resolved_at IS '해결 확인 시각';

-- ---------------------------------------------------------------- 초기 데이터
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

COMMIT;

-- 운영 계정 권한 (원장 보호, INV-01):
-- REVOKE UPDATE, DELETE ON inventory.ledger_entries FROM app_user;
