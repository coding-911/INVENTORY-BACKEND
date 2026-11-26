-- ============================================================
-- 자산관리 시스템 DDL — ERDCloud 가져오기용 (MySQL 8 문법)
-- 운영 DB는 PostgreSQL. 이 파일은 ERD 작성용으로 단순화한 버전이다.
-- 차이: 스키마 접두어 생략(테이블 주석에 [스키마] 표기), 부분 유니크 인덱스·
--       UNIQUE NULLS NOT DISTINCT·원장 보호 트리거·초기 데이터 생략
-- ============================================================

SET FOREIGN_KEY_CHECKS = 0;

CREATE TABLE `users` (
    `id` CHAR(36) NOT NULL DEFAULT (UUID()) COMMENT 'ID (UUID v7, 앱에서 생성. DB 기본값도 v7, PostgreSQL 18)',
    `login_id` VARCHAR(50) NOT NULL COMMENT '로그인 ID',
    `name` VARCHAR(100) NOT NULL COMMENT '이름',
    `email` VARCHAR(200) NULL COMMENT '이메일',
    `password_hash` VARCHAR(200) NOT NULL COMMENT '비밀번호 해시',
    `is_active` BOOLEAN NOT NULL DEFAULT TRUE COMMENT '사용 여부',
    `last_login_at` DATETIME(6) NULL COMMENT '마지막 로그인',
    `tokens_valid_after` DATETIME(6) NULL COMMENT '토큰 무효 기준 시각',
    `must_change_password` BOOLEAN NOT NULL DEFAULT FALSE COMMENT '다음 로그인 때 비밀번호 변경 필요',
    `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '생성 시각',
    `created_by` CHAR(36) NOT NULL COMMENT '생성자',
    `updated_at` DATETIME(6) NULL COMMENT '수정 시각',
    `updated_by` CHAR(36) NULL COMMENT '수정자',
    `version` INT NOT NULL DEFAULT 0 COMMENT '버전(낙관적 잠금)',
    `deleted_at` DATETIME(6) NULL COMMENT '삭제 시각',
    `deleted_by` CHAR(36) NULL COMMENT '삭제자',
    PRIMARY KEY (`id`)
) COMMENT = '[auth] 사용자';

CREATE TABLE `roles` (
    `id` CHAR(36) NOT NULL DEFAULT (UUID()) COMMENT 'ID (UUID v7, 앱에서 생성. DB 기본값도 v7, PostgreSQL 18)',
    `code` VARCHAR(30) NOT NULL COMMENT '역할 코드',
    `name` VARCHAR(100) NOT NULL COMMENT '역할명',
    PRIMARY KEY (`id`),
    UNIQUE KEY `uq_roles_code` (`code`)
) COMMENT = '[auth] 역할';

CREATE TABLE `user_roles` (
    `user_id` CHAR(36) NOT NULL COMMENT '사용자',
    `role_id` CHAR(36) NOT NULL COMMENT '역할',
    PRIMARY KEY (`user_id`, `role_id`),
    CONSTRAINT `fk_user_roles_user_id` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`),
    CONSTRAINT `fk_user_roles_role_id` FOREIGN KEY (`role_id`) REFERENCES `roles` (`id`)
) COMMENT = '[auth] 사용자 역할';

CREATE TABLE `user_permissions` (
    `user_id` CHAR(36) NOT NULL COMMENT '사용자',
    `permission` VARCHAR(30) NOT NULL COMMENT '권한(COST_VIEW/COST_EDIT)',
    PRIMARY KEY (`user_id`, `permission`),
    CONSTRAINT `fk_user_permissions_user_id` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`),
    CONSTRAINT `ck_user_permissions_1` CHECK (permission IN ('COST_VIEW', 'COST_EDIT'))
) COMMENT = '[auth] 사용자 추가 권한';

CREATE TABLE `oauth2_authorization` (
    `id` VARCHAR(100) NOT NULL COMMENT '인가 ID',
    `registered_client_id` VARCHAR(100) NOT NULL COMMENT '클라이언트 ID',
    `principal_name` VARCHAR(200) NOT NULL COMMENT '사용자(로그인 ID)',
    `authorization_grant_type` VARCHAR(100) NOT NULL COMMENT '인가 방식',
    `authorized_scopes` VARCHAR(1000) NULL COMMENT '허용 범위',
    `attributes` TEXT NULL COMMENT '속성',
    `state` VARCHAR(500) NULL COMMENT '상태 값',
    `authorization_code_value` TEXT NULL COMMENT '인가 코드',
    `authorization_code_issued_at` TIMESTAMP NULL COMMENT '인가 코드 발급 시각',
    `authorization_code_expires_at` TIMESTAMP NULL COMMENT '인가 코드 만료 시각',
    `authorization_code_metadata` TEXT NULL COMMENT '인가 코드 메타데이터',
    `access_token_value` TEXT NULL COMMENT 'access token',
    `access_token_issued_at` TIMESTAMP NULL COMMENT 'access token 발급 시각',
    `access_token_expires_at` TIMESTAMP NULL COMMENT 'access token 만료 시각',
    `access_token_metadata` TEXT NULL COMMENT 'access token 메타데이터',
    `access_token_type` VARCHAR(100) NULL COMMENT 'access token 유형',
    `access_token_scopes` VARCHAR(1000) NULL COMMENT 'access token 범위',
    `oidc_id_token_value` TEXT NULL COMMENT 'ID 토큰',
    `oidc_id_token_issued_at` TIMESTAMP NULL COMMENT 'ID 토큰 발급 시각',
    `oidc_id_token_expires_at` TIMESTAMP NULL COMMENT 'ID 토큰 만료 시각',
    `oidc_id_token_metadata` TEXT NULL COMMENT 'ID 토큰 메타데이터',
    `refresh_token_value` TEXT NULL COMMENT 'refresh token',
    `refresh_token_issued_at` TIMESTAMP NULL COMMENT 'refresh token 발급 시각',
    `refresh_token_expires_at` TIMESTAMP NULL COMMENT 'refresh token 만료 시각',
    `refresh_token_metadata` TEXT NULL COMMENT 'refresh token 메타데이터',
    `user_code_value` TEXT NULL COMMENT '기기 인증 사용자 코드',
    `user_code_issued_at` TIMESTAMP NULL COMMENT '사용자 코드 발급 시각',
    `user_code_expires_at` TIMESTAMP NULL COMMENT '사용자 코드 만료 시각',
    `user_code_metadata` TEXT NULL COMMENT '사용자 코드 메타데이터',
    `device_code_value` TEXT NULL COMMENT '기기 코드',
    `device_code_issued_at` TIMESTAMP NULL COMMENT '기기 코드 발급 시각',
    `device_code_expires_at` TIMESTAMP NULL COMMENT '기기 코드 만료 시각',
    `device_code_metadata` TEXT NULL COMMENT '기기 코드 메타데이터',
    PRIMARY KEY (`id`)
) COMMENT = '[auth] 로그인 토큰(Spring Authorization Server)';

CREATE TABLE `product_categories` (
    `id` CHAR(36) NOT NULL DEFAULT (UUID()) COMMENT 'ID (UUID v7, 앱에서 생성. DB 기본값도 v7, PostgreSQL 18)',
    `code` VARCHAR(30) NOT NULL COMMENT '품목군 코드',
    `name` VARCHAR(100) NOT NULL COMMENT '품목군명',
    `sort_order` INT NOT NULL DEFAULT 0 COMMENT '표시 순서',
    `is_active` BOOLEAN NOT NULL DEFAULT TRUE COMMENT '사용 여부',
    `deleted_at` DATETIME(6) NULL COMMENT '삭제 시각',
    `deleted_by` CHAR(36) NULL COMMENT '삭제자',
    PRIMARY KEY (`id`)
) COMMENT = '[product] 품목군';

CREATE TABLE `products` (
    `id` CHAR(36) NOT NULL DEFAULT (UUID()) COMMENT 'ID (UUID v7, 앱에서 생성. DB 기본값도 v7, PostgreSQL 18)',
    `item_code` VARCHAR(50) NOT NULL COMMENT 'Item Code(앞자리 0 보존)',
    `product_name` VARCHAR(200) NOT NULL COMMENT '제품명',
    `model_name` VARCHAR(100) NULL COMMENT '모델명',
    `category_id` CHAR(36) NOT NULL COMMENT '품목군',
    `manufacturer` VARCHAR(100) NULL COMMENT '제조사',
    `component_role` VARCHAR(100) NULL COMMENT '구성품 역할',
    `specification` TEXT NULL COMMENT '규격/설명',
    `unit` VARCHAR(20) NOT NULL DEFAULT 'EA' COMMENT '단위',
    `serial_managed` BOOLEAN NOT NULL DEFAULT FALSE COMMENT '시리얼 관리 여부',
    `is_active` BOOLEAN NOT NULL DEFAULT TRUE COMMENT '사용 여부',
    `note` TEXT NULL COMMENT '비고',
    `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '생성 시각',
    `created_by` CHAR(36) NOT NULL COMMENT '생성자',
    `updated_at` DATETIME(6) NULL COMMENT '수정 시각',
    `updated_by` CHAR(36) NULL COMMENT '수정자',
    `version` INT NOT NULL DEFAULT 0 COMMENT '버전(낙관적 잠금)',
    `deleted_at` DATETIME(6) NULL COMMENT '삭제 시각',
    `deleted_by` CHAR(36) NULL COMMENT '삭제자',
    PRIMARY KEY (`id`),
    CONSTRAINT `fk_products_category_id` FOREIGN KEY (`category_id`) REFERENCES `product_categories` (`id`)
) COMMENT = '[product] 제품';

CREATE TABLE `product_changes` (
    `id` CHAR(36) NOT NULL DEFAULT (UUID()) COMMENT 'ID (UUID v7, 앱에서 생성. DB 기본값도 v7, PostgreSQL 18)',
    `product_id` CHAR(36) NOT NULL COMMENT '제품',
    `field_name` VARCHAR(50) NOT NULL COMMENT '변경 항목',
    `old_value` TEXT NULL COMMENT '이전 값',
    `new_value` TEXT NULL COMMENT '새 값',
    `reason` TEXT NULL COMMENT '사유',
    `changed_by` CHAR(36) NOT NULL COMMENT '변경자',
    `changed_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '변경 시각',
    PRIMARY KEY (`id`),
    CONSTRAINT `fk_product_changes_product_id` FOREIGN KEY (`product_id`) REFERENCES `products` (`id`)
) COMMENT = '[product] 제품 변경 이력';

CREATE TABLE `bundles` (
    `id` CHAR(36) NOT NULL DEFAULT (UUID()) COMMENT 'ID (UUID v7, 앱에서 생성. DB 기본값도 v7, PostgreSQL 18)',
    `bundle_code` VARCHAR(30) NOT NULL COMMENT '묶음 코드',
    `bundle_name` VARCHAR(200) NOT NULL COMMENT '묶음명',
    `is_active` BOOLEAN NOT NULL DEFAULT TRUE COMMENT '사용 여부',
    `note` TEXT NULL COMMENT '비고',
    `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '생성 시각',
    `created_by` CHAR(36) NOT NULL COMMENT '생성자',
    `updated_at` DATETIME(6) NULL COMMENT '수정 시각',
    `updated_by` CHAR(36) NULL COMMENT '수정자',
    `version` INT NOT NULL DEFAULT 0 COMMENT '버전(낙관적 잠금)',
    `deleted_at` DATETIME(6) NULL COMMENT '삭제 시각',
    `deleted_by` CHAR(36) NULL COMMENT '삭제자',
    PRIMARY KEY (`id`)
) COMMENT = '[product] 구성 묶음';

CREATE TABLE `bundle_components` (
    `id` CHAR(36) NOT NULL DEFAULT (UUID()) COMMENT 'ID (UUID v7, 앱에서 생성. DB 기본값도 v7, PostgreSQL 18)',
    `bundle_id` CHAR(36) NOT NULL COMMENT '묶음',
    `product_id` CHAR(36) NOT NULL COMMENT '구성품',
    `quantity_per_set` INT NOT NULL COMMENT '세트당 수량',
    PRIMARY KEY (`id`),
    UNIQUE KEY `uq_bundle_components_bundle_id_product_id` (`bundle_id`, `product_id`),
    CONSTRAINT `fk_bundle_components_bundle_id` FOREIGN KEY (`bundle_id`) REFERENCES `bundles` (`id`),
    CONSTRAINT `fk_bundle_components_product_id` FOREIGN KEY (`product_id`) REFERENCES `products` (`id`),
    CONSTRAINT `ck_bundle_components_1` CHECK (quantity_per_set > 0)
) COMMENT = '[product] 구성 묶음 구성품';

CREATE TABLE `warehouses` (
    `id` CHAR(36) NOT NULL DEFAULT (UUID()) COMMENT 'ID (UUID v7, 앱에서 생성. DB 기본값도 v7, PostgreSQL 18)',
    `warehouse_code` VARCHAR(30) NOT NULL COMMENT '창고 코드',
    `warehouse_name` VARCHAR(100) NOT NULL COMMENT '창고명',
    `address` VARCHAR(300) NULL COMMENT '주소',
    `is_active` BOOLEAN NOT NULL DEFAULT TRUE COMMENT '사용 여부',
    `note` TEXT NULL COMMENT '비고',
    `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '생성 시각',
    `created_by` CHAR(36) NOT NULL COMMENT '생성자',
    `updated_at` DATETIME(6) NULL COMMENT '수정 시각',
    `updated_by` CHAR(36) NULL COMMENT '수정자',
    `version` INT NOT NULL DEFAULT 0 COMMENT '버전(낙관적 잠금)',
    `deleted_at` DATETIME(6) NULL COMMENT '삭제 시각',
    `deleted_by` CHAR(36) NULL COMMENT '삭제자',
    PRIMARY KEY (`id`)
) COMMENT = '[warehouse] 창고';

CREATE TABLE `locations` (
    `id` CHAR(36) NOT NULL DEFAULT (UUID()) COMMENT 'ID (UUID v7, 앱에서 생성. DB 기본값도 v7, PostgreSQL 18)',
    `location_code` VARCHAR(30) NOT NULL COMMENT '위치 코드',
    `location_name` VARCHAR(100) NOT NULL COMMENT '위치명',
    `location_type` VARCHAR(20) NOT NULL DEFAULT 'INTERNAL' COMMENT '위치 유형',
    `warehouse_id` CHAR(36) NULL COMMENT '창고(자사 위치)',
    `partner_id` CHAR(36) NULL COMMENT '상대 업체(외부 위치)',
    `zone` VARCHAR(30) NULL COMMENT '구역',
    `rack` VARCHAR(30) NULL COMMENT '랙',
    `shelf` VARCHAR(30) NULL COMMENT '선반',
    `is_active` BOOLEAN NOT NULL DEFAULT TRUE COMMENT '사용 여부',
    `note` TEXT NULL COMMENT '비고',
    `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '생성 시각',
    `created_by` CHAR(36) NOT NULL COMMENT '생성자',
    `updated_at` DATETIME(6) NULL COMMENT '수정 시각',
    `updated_by` CHAR(36) NULL COMMENT '수정자',
    `version` INT NOT NULL DEFAULT 0 COMMENT '버전(낙관적 잠금)',
    `deleted_at` DATETIME(6) NULL COMMENT '삭제 시각',
    `deleted_by` CHAR(36) NULL COMMENT '삭제자',
    PRIMARY KEY (`id`),
    CONSTRAINT `fk_locations_warehouse_id` FOREIGN KEY (`warehouse_id`) REFERENCES `warehouses` (`id`),
    CONSTRAINT `fk_locations_partner_id` FOREIGN KEY (`partner_id`) REFERENCES `partners` (`id`),
    CONSTRAINT `ck_locations_1` CHECK (location_type IN ('INTERNAL', 'REPAIR', 'LOAN_OUT', 'CUSTOMER_SITE')),
    CONSTRAINT `ck_locations_2` CHECK ((location_type = 'INTERNAL' AND warehouse_id IS NOT NULL AND partner_id IS NULL) OR (location_type <> 'INTERNAL' AND partner_id IS NOT NULL))
) COMMENT = '[warehouse] 위치(자사 창고 내 위치 + 외부 위치)';

CREATE TABLE `partners` (
    `id` CHAR(36) NOT NULL DEFAULT (UUID()) COMMENT 'ID (UUID v7, 앱에서 생성. DB 기본값도 v7, PostgreSQL 18)',
    `partner_name` VARCHAR(200) NOT NULL COMMENT '거래처명',
    `business_reg_no` VARCHAR(20) NULL COMMENT '사업자등록번호',
    `address` VARCHAR(300) NULL COMMENT '주소',
    `phone` VARCHAR(50) NULL COMMENT '대표 번호',
    `is_active` BOOLEAN NOT NULL DEFAULT TRUE COMMENT '사용 여부',
    `note` TEXT NULL COMMENT '비고',
    `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '생성 시각',
    `created_by` CHAR(36) NOT NULL COMMENT '생성자',
    `updated_at` DATETIME(6) NULL COMMENT '수정 시각',
    `updated_by` CHAR(36) NULL COMMENT '수정자',
    `version` INT NOT NULL DEFAULT 0 COMMENT '버전(낙관적 잠금)',
    `deleted_at` DATETIME(6) NULL COMMENT '삭제 시각',
    `deleted_by` CHAR(36) NULL COMMENT '삭제자',
    PRIMARY KEY (`id`)
) COMMENT = '[partner] 거래처';

CREATE TABLE `partner_roles` (
    `partner_id` CHAR(36) NOT NULL COMMENT '거래처',
    `role` VARCHAR(20) NOT NULL COMMENT '역할(고객사/공급사)',
    PRIMARY KEY (`partner_id`, `role`),
    CONSTRAINT `fk_partner_roles_partner_id` FOREIGN KEY (`partner_id`) REFERENCES `partners` (`id`),
    CONSTRAINT `ck_partner_roles_1` CHECK (role IN ('CUSTOMER', 'SUPPLIER'))
) COMMENT = '[partner] 거래처 역할';

CREATE TABLE `contacts` (
    `id` CHAR(36) NOT NULL DEFAULT (UUID()) COMMENT 'ID (UUID v7, 앱에서 생성. DB 기본값도 v7, PostgreSQL 18)',
    `partner_id` CHAR(36) NOT NULL COMMENT '거래처',
    `name` VARCHAR(100) NOT NULL COMMENT '담당자명',
    `department` VARCHAR(100) NULL COMMENT '소속',
    `position` VARCHAR(100) NULL COMMENT '직위',
    `phone` VARCHAR(50) NULL COMMENT '번호',
    `email` VARCHAR(200) NULL COMMENT '이메일',
    `is_primary` BOOLEAN NOT NULL DEFAULT FALSE COMMENT '주 담당자',
    `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '생성 시각',
    `created_by` CHAR(36) NOT NULL COMMENT '생성자',
    `updated_at` DATETIME(6) NULL COMMENT '수정 시각',
    `updated_by` CHAR(36) NULL COMMENT '수정자',
    `version` INT NOT NULL DEFAULT 0 COMMENT '버전(낙관적 잠금)',
    `deleted_at` DATETIME(6) NULL COMMENT '삭제 시각',
    `deleted_by` CHAR(36) NULL COMMENT '삭제자',
    PRIMARY KEY (`id`),
    CONSTRAINT `fk_contacts_partner_id` FOREIGN KEY (`partner_id`) REFERENCES `partners` (`id`)
) COMMENT = '[partner] 거래처 담당자';

CREATE TABLE `stock_transactions` (
    `id` CHAR(36) NOT NULL DEFAULT (UUID()) COMMENT 'ID (UUID v7, 앱에서 생성. DB 기본값도 v7, PostgreSQL 18)',
    `transaction_no` VARCHAR(30) NOT NULL COMMENT '처리 번호',
    `transaction_type` VARCHAR(30) NOT NULL COMMENT '처리 유형',
    `business_date` DATE NOT NULL COMMENT '업무 날짜',
    `status` VARCHAR(10) NOT NULL DEFAULT 'DRAFT' COMMENT '상태(임시/확정)',
    `request_id` VARCHAR(64) NOT NULL COMMENT '중복 요청 방지 키',
    `related_transaction_id` CHAR(36) NULL COMMENT '취소·정정 원본 묶음',
    `source_type` VARCHAR(30) NULL COMMENT '출처 유형',
    `source_id` CHAR(36) NULL COMMENT '출처 ID',
    `counterparty_partner_id` CHAR(36) NULL COMMENT '상대 거래처',
    `reason_code` VARCHAR(30) NULL COMMENT '사유 코드',
    `reason` TEXT NULL COMMENT '사유',
    `reference_no` VARCHAR(100) NULL COMMENT '외부 문서번호',
    `approved_by` CHAR(36) NULL COMMENT '승인자',
    `approved_at` DATETIME(6) NULL COMMENT '승인 시각',
    `note` TEXT NULL COMMENT '비고',
    `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '생성 시각',
    `created_by` CHAR(36) NOT NULL COMMENT '생성자',
    `posted_at` DATETIME(6) NULL COMMENT '확정 시각',
    `posted_by` CHAR(36) NULL COMMENT '확정자',
    PRIMARY KEY (`id`),
    UNIQUE KEY `uq_stock_transactions_transaction_no` (`transaction_no`),
    UNIQUE KEY `uq_stock_transactions_request_id` (`request_id`),
    CONSTRAINT `fk_stock_transactions_related_transaction_id` FOREIGN KEY (`related_transaction_id`) REFERENCES `stock_transactions` (`id`),
    CONSTRAINT `fk_stock_transactions_counterparty_partner_id` FOREIGN KEY (`counterparty_partner_id`) REFERENCES `partners` (`id`),
    CONSTRAINT `ck_stock_transactions_1` CHECK (transaction_type IN ('OPENING', 'RECEIPT', 'UNPLANNED_RECEIPT', 'ISSUE', 'TRANSFER', 'ADJUSTMENT', 'CUSTOMER_RETURN', 'INSPECTION_RESULT', 'SUPPLIER_RETURN', 'REPAIR_OUT', 'REPAIR_IN', 'EXCHANGE', 'DISPOSAL', 'LOAN_IN_RECEIPT', 'LOAN_IN_REPAY', 'LOAN_IN_RETURN', 'TEMP_INSTALL', 'LOAN_OUT_ISSUE', 'LOAN_OUT_RETURN', 'LOAN_OUT_SETTLE', 'OWNERSHIP_TRANSFER', 'REVERSAL', 'CORRECTION')),
    CONSTRAINT `ck_stock_transactions_2` CHECK (status IN ('DRAFT', 'POSTED'))
) COMMENT = '[inventory] 처리 묶음(원장 헤더)';

CREATE TABLE `ledger_entries` (
    `id` CHAR(36) NOT NULL DEFAULT (UUID()) COMMENT 'ID (UUID v7, 앱에서 생성. DB 기본값도 v7, PostgreSQL 18)',
    `transaction_id` CHAR(36) NOT NULL COMMENT '처리 묶음',
    `line_no` INT NOT NULL COMMENT '행 번호',
    `product_id` CHAR(36) NOT NULL COMMENT '제품',
    `location_id` CHAR(36) NOT NULL COMMENT '위치',
    `stock_condition` VARCHAR(20) NOT NULL COMMENT '재고 상태',
    `owner_type` VARCHAR(20) NOT NULL DEFAULT 'OWN' COMMENT '소유 구분(자사/타사)',
    `owner_partner_id` CHAR(36) NULL COMMENT '타사 소유 업체',
    `quantity_delta` INT NOT NULL COMMENT '수량 증감(+입고/-출고)',
    `business_date` DATE NOT NULL COMMENT '업무 날짜',
    `equipment_id` CHAR(36) NULL COMMENT '개별 장비',
    `pair_id` CHAR(36) NULL COMMENT '쌍 처리 묶음 ID',
    `reversal_of_entry_id` CHAR(36) NULL COMMENT '취소 대상 원장 행',
    `trade_line_id` CHAR(36) NULL COMMENT '연결 거래 품목(참조)',
    `lot_no` VARCHAR(50) NULL COMMENT '로트 번호',
    `item_code_snapshot` VARCHAR(50) NOT NULL COMMENT '처리 당시 Item Code',
    `product_name_snapshot` VARCHAR(200) NOT NULL COMMENT '처리 당시 제품명',
    `note` TEXT NULL COMMENT '비고',
    `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '생성 시각',
    `created_by` CHAR(36) NOT NULL COMMENT '생성자',
    PRIMARY KEY (`id`),
    UNIQUE KEY `uq_ledger_entries_transaction_id_line_no` (`transaction_id`, `line_no`),
    UNIQUE KEY `uq_ledger_entries_reversal_of_entry_id` (`reversal_of_entry_id`),
    CONSTRAINT `fk_ledger_entries_transaction_id` FOREIGN KEY (`transaction_id`) REFERENCES `stock_transactions` (`id`),
    CONSTRAINT `fk_ledger_entries_product_id` FOREIGN KEY (`product_id`) REFERENCES `products` (`id`),
    CONSTRAINT `fk_ledger_entries_location_id` FOREIGN KEY (`location_id`) REFERENCES `locations` (`id`),
    CONSTRAINT `fk_ledger_entries_owner_partner_id` FOREIGN KEY (`owner_partner_id`) REFERENCES `partners` (`id`),
    CONSTRAINT `fk_ledger_entries_equipment_id` FOREIGN KEY (`equipment_id`) REFERENCES `equipment` (`id`),
    CONSTRAINT `fk_ledger_entries_reversal_of_entry_id` FOREIGN KEY (`reversal_of_entry_id`) REFERENCES `ledger_entries` (`id`),
    CONSTRAINT `ck_ledger_entries_1` CHECK (stock_condition IN ('AVAILABLE', 'INSPECTION', 'DEFECTIVE', 'IN_REPAIR')),
    CONSTRAINT `ck_ledger_entries_2` CHECK (owner_type IN ('OWN', 'THIRD_PARTY')),
    CONSTRAINT `ck_ledger_entries_3` CHECK ((owner_type = 'OWN' AND owner_partner_id IS NULL) OR (owner_type = 'THIRD_PARTY' AND owner_partner_id IS NOT NULL)),
    CONSTRAINT `ck_ledger_entries_4` CHECK (quantity_delta <> 0)
) COMMENT = '[inventory] 재고 원장(INSERT 전용)';

CREATE TABLE `stock_balances` (
    `id` CHAR(36) NOT NULL DEFAULT (UUID()) COMMENT 'ID (UUID v7, 앱에서 생성. DB 기본값도 v7, PostgreSQL 18)',
    `product_id` CHAR(36) NOT NULL COMMENT '제품',
    `location_id` CHAR(36) NOT NULL COMMENT '위치',
    `stock_condition` VARCHAR(20) NOT NULL COMMENT '재고 상태',
    `owner_type` VARCHAR(20) NOT NULL DEFAULT 'OWN' COMMENT '소유 구분(자사/타사)',
    `owner_partner_id` CHAR(36) NULL COMMENT '타사 소유 업체',
    `quantity` INT NOT NULL DEFAULT 0 COMMENT '수량',
    `updated_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '갱신 시각',
    PRIMARY KEY (`id`),
    CONSTRAINT `fk_stock_balances_product_id` FOREIGN KEY (`product_id`) REFERENCES `products` (`id`),
    CONSTRAINT `fk_stock_balances_location_id` FOREIGN KEY (`location_id`) REFERENCES `locations` (`id`),
    CONSTRAINT `fk_stock_balances_owner_partner_id` FOREIGN KEY (`owner_partner_id`) REFERENCES `partners` (`id`),
    CONSTRAINT `ck_stock_balances_1` CHECK (stock_condition IN ('AVAILABLE', 'INSPECTION', 'DEFECTIVE', 'IN_REPAIR')),
    CONSTRAINT `ck_stock_balances_2` CHECK (owner_type IN ('OWN', 'THIRD_PARTY')),
    CONSTRAINT `ck_stock_balances_3` CHECK ((owner_type = 'OWN' AND owner_partner_id IS NULL) OR (owner_type = 'THIRD_PARTY' AND owner_partner_id IS NOT NULL)),
    CONSTRAINT `ck_stock_balances_4` CHECK (quantity >= 0)
) COMMENT = '[inventory] 현재 재고(잠금 대상)';

CREATE TABLE `period_closings` (
    `id` CHAR(36) NOT NULL DEFAULT (UUID()) COMMENT 'ID (UUID v7, 앱에서 생성. DB 기본값도 v7, PostgreSQL 18)',
    `period` CHAR(7) NOT NULL COMMENT '기간(YYYY-MM)',
    `status` VARCHAR(10) NOT NULL DEFAULT 'OPEN' COMMENT '상태',
    `closed_at` DATETIME(6) NULL COMMENT '마감 시각',
    `closed_by` CHAR(36) NULL COMMENT '마감자',
    `snapshot_version` INT NOT NULL DEFAULT 0 COMMENT '스냅샷 버전',
    PRIMARY KEY (`id`),
    UNIQUE KEY `uq_period_closings_period` (`period`),
    CONSTRAINT `ck_period_closings_1` CHECK (status IN ('OPEN', 'CLOSED'))
) COMMENT = '[inventory] 월 마감';

CREATE TABLE `period_closing_events` (
    `id` CHAR(36) NOT NULL DEFAULT (UUID()) COMMENT 'ID (UUID v7, 앱에서 생성. DB 기본값도 v7, PostgreSQL 18)',
    `period` CHAR(7) NOT NULL COMMENT '기간',
    `action` VARCHAR(10) NOT NULL COMMENT '동작(마감/해제)',
    `reason` TEXT NULL COMMENT '사유',
    `acted_by` CHAR(36) NOT NULL COMMENT '처리자',
    `acted_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '처리 시각',
    PRIMARY KEY (`id`),
    CONSTRAINT `fk_period_closing_events_period` FOREIGN KEY (`period`) REFERENCES `period_closings` (`period`),
    CONSTRAINT `ck_period_closing_events_1` CHECK (action IN ('CLOSE', 'REOPEN'))
) COMMENT = '[inventory] 마감·해제 이력';

CREATE TABLE `monthly_stock_snapshots` (
    `id` CHAR(36) NOT NULL DEFAULT (UUID()) COMMENT 'ID (UUID v7, 앱에서 생성. DB 기본값도 v7, PostgreSQL 18)',
    `period` CHAR(7) NOT NULL COMMENT '기간',
    `snapshot_version` INT NOT NULL COMMENT '스냅샷 버전',
    `product_id` CHAR(36) NOT NULL COMMENT '제품',
    `location_id` CHAR(36) NOT NULL COMMENT '위치',
    `stock_condition` VARCHAR(20) NOT NULL COMMENT '재고 상태',
    `owner_type` VARCHAR(20) NOT NULL DEFAULT 'OWN' COMMENT '소유 구분(자사/타사)',
    `owner_partner_id` CHAR(36) NULL COMMENT '타사 소유 업체',
    `quantity` INT NOT NULL COMMENT '수량',
    PRIMARY KEY (`id`),
    CONSTRAINT `fk_monthly_stock_snapshots_product_id` FOREIGN KEY (`product_id`) REFERENCES `products` (`id`),
    CONSTRAINT `fk_monthly_stock_snapshots_location_id` FOREIGN KEY (`location_id`) REFERENCES `locations` (`id`),
    CONSTRAINT `fk_monthly_stock_snapshots_owner_partner_id` FOREIGN KEY (`owner_partner_id`) REFERENCES `partners` (`id`)
) COMMENT = '[inventory] 월말 재고 스냅샷';

CREATE TABLE `stock_counts` (
    `id` CHAR(36) NOT NULL DEFAULT (UUID()) COMMENT 'ID (UUID v7, 앱에서 생성. DB 기본값도 v7, PostgreSQL 18)',
    `count_no` VARCHAR(30) NOT NULL COMMENT '실사 번호',
    `scope_type` VARCHAR(20) NOT NULL COMMENT '범위 유형',
    `base_date` DATE NOT NULL COMMENT '실사 기준일',
    `assignee_id` CHAR(36) NOT NULL COMMENT '담당자',
    `status` VARCHAR(20) NOT NULL DEFAULT 'PREPARED' COMMENT '상태',
    `started_at` DATETIME(6) NULL COMMENT '시작 시각',
    `approved_by` CHAR(36) NULL COMMENT '승인자',
    `approved_at` DATETIME(6) NULL COMMENT '승인 시각',
    `adjustment_transaction_id` CHAR(36) NULL COMMENT '실사 조정 묶음',
    `note` TEXT NULL COMMENT '비고',
    `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '생성 시각',
    `created_by` CHAR(36) NOT NULL COMMENT '생성자',
    `updated_at` DATETIME(6) NULL COMMENT '수정 시각',
    `updated_by` CHAR(36) NULL COMMENT '수정자',
    `version` INT NOT NULL DEFAULT 0 COMMENT '버전(낙관적 잠금)',
    PRIMARY KEY (`id`),
    UNIQUE KEY `uq_stock_counts_count_no` (`count_no`),
    CONSTRAINT `fk_stock_counts_adjustment_transaction_id` FOREIGN KEY (`adjustment_transaction_id`) REFERENCES `stock_transactions` (`id`),
    CONSTRAINT `ck_stock_counts_1` CHECK (scope_type IN ('LOCATION', 'PRODUCT')),
    CONSTRAINT `ck_stock_counts_2` CHECK (status IN ('PREPARED', 'IN_PROGRESS', 'REVIEW', 'APPROVED', 'CANCELLED'))
) COMMENT = '[inventory] 재고 실사';

CREATE TABLE `stock_count_scopes` (
    `id` CHAR(36) NOT NULL DEFAULT (UUID()) COMMENT 'ID (UUID v7, 앱에서 생성. DB 기본값도 v7, PostgreSQL 18)',
    `count_id` CHAR(36) NOT NULL COMMENT '실사',
    `location_id` CHAR(36) NULL COMMENT '위치',
    `product_id` CHAR(36) NULL COMMENT '제품',
    PRIMARY KEY (`id`),
    CONSTRAINT `fk_stock_count_scopes_count_id` FOREIGN KEY (`count_id`) REFERENCES `stock_counts` (`id`),
    CONSTRAINT `fk_stock_count_scopes_location_id` FOREIGN KEY (`location_id`) REFERENCES `locations` (`id`),
    CONSTRAINT `fk_stock_count_scopes_product_id` FOREIGN KEY (`product_id`) REFERENCES `products` (`id`),
    CONSTRAINT `ck_stock_count_scopes_1` CHECK (location_id IS NOT NULL OR product_id IS NOT NULL)
) COMMENT = '[inventory] 실사 잠금 범위';

CREATE TABLE `stock_count_lines` (
    `id` CHAR(36) NOT NULL DEFAULT (UUID()) COMMENT 'ID (UUID v7, 앱에서 생성. DB 기본값도 v7, PostgreSQL 18)',
    `count_id` CHAR(36) NOT NULL COMMENT '실사',
    `product_id` CHAR(36) NOT NULL COMMENT '제품',
    `location_id` CHAR(36) NOT NULL COMMENT '위치',
    `stock_condition` VARCHAR(20) NOT NULL COMMENT '재고 상태',
    `owner_type` VARCHAR(20) NOT NULL DEFAULT 'OWN' COMMENT '소유 구분(자사/타사)',
    `owner_partner_id` CHAR(36) NULL COMMENT '타사 소유 업체',
    `book_quantity` INT NOT NULL COMMENT '장부 수량(시작 시점)',
    `counted_quantity` INT NULL COMMENT '실물 수량',
    `recounted` BOOLEAN NOT NULL DEFAULT FALSE COMMENT '재실사 여부',
    `note` TEXT NULL COMMENT '비고',
    PRIMARY KEY (`id`),
    CONSTRAINT `fk_stock_count_lines_count_id` FOREIGN KEY (`count_id`) REFERENCES `stock_counts` (`id`),
    CONSTRAINT `fk_stock_count_lines_product_id` FOREIGN KEY (`product_id`) REFERENCES `products` (`id`),
    CONSTRAINT `fk_stock_count_lines_location_id` FOREIGN KEY (`location_id`) REFERENCES `locations` (`id`),
    CONSTRAINT `fk_stock_count_lines_owner_partner_id` FOREIGN KEY (`owner_partner_id`) REFERENCES `partners` (`id`),
    CONSTRAINT `ck_stock_count_lines_1` CHECK (stock_condition IN ('AVAILABLE', 'INSPECTION', 'DEFECTIVE', 'IN_REPAIR')),
    CONSTRAINT `ck_stock_count_lines_2` CHECK (owner_type IN ('OWN', 'THIRD_PARTY')),
    CONSTRAINT `ck_stock_count_lines_3` CHECK ((owner_type = 'OWN' AND owner_partner_id IS NULL) OR (owner_type = 'THIRD_PARTY' AND owner_partner_id IS NOT NULL))
) COMMENT = '[inventory] 실사 품목';

CREATE TABLE `stock_count_serials` (
    `id` CHAR(36) NOT NULL DEFAULT (UUID()) COMMENT 'ID (UUID v7, 앱에서 생성. DB 기본값도 v7, PostgreSQL 18)',
    `count_id` CHAR(36) NOT NULL COMMENT '실사',
    `line_id` CHAR(36) NOT NULL COMMENT '실사 품목',
    `serial_no` VARCHAR(100) NOT NULL COMMENT '시리얼',
    `equipment_id` CHAR(36) NULL COMMENT '장비',
    `result` VARCHAR(20) NOT NULL COMMENT '대조 결과',
    PRIMARY KEY (`id`),
    CONSTRAINT `fk_stock_count_serials_count_id` FOREIGN KEY (`count_id`) REFERENCES `stock_counts` (`id`),
    CONSTRAINT `fk_stock_count_serials_line_id` FOREIGN KEY (`line_id`) REFERENCES `stock_count_lines` (`id`),
    CONSTRAINT `fk_stock_count_serials_equipment_id` FOREIGN KEY (`equipment_id`) REFERENCES `equipment` (`id`),
    CONSTRAINT `ck_stock_count_serials_1` CHECK (result IN ('MATCHED', 'MISSING', 'UNEXPECTED'))
) COMMENT = '[inventory] 실사 시리얼 대조';

CREATE TABLE `equipment` (
    `id` CHAR(36) NOT NULL DEFAULT (UUID()) COMMENT 'ID (UUID v7, 앱에서 생성. DB 기본값도 v7, PostgreSQL 18)',
    `product_id` CHAR(36) NOT NULL COMMENT '제품',
    `serial_no` VARCHAR(100) NULL COMMENT '시리얼 번호(미확인 시 NULL)',
    `serial_status` VARCHAR(20) NOT NULL DEFAULT 'CONFIRMED' COMMENT '시리얼 확인 상태',
    `status` VARCHAR(30) NOT NULL COMMENT '장비 상태',
    `current_location_id` CHAR(36) NULL COMMENT '현재 위치',
    `owner_type` VARCHAR(20) NOT NULL DEFAULT 'OWN' COMMENT '소유 구분(자사/타사)',
    `owner_partner_id` CHAR(36) NULL COMMENT '타사 소유 업체',
    `project_id` CHAR(36) NULL COMMENT '프로젝트',
    `delivered_partner_id` CHAR(36) NULL COMMENT '납품처',
    `replaced_by_equipment_id` CHAR(36) NULL COMMENT '교체된 새 장비',
    `origin_type` VARCHAR(30) NOT NULL DEFAULT 'LEDGER' COMMENT '생성 경로(원장/기준일 이전 납품)',
    `last_event_date` DATE NOT NULL COMMENT '마지막 처리 날짜',
    `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '생성 시각',
    `created_by` CHAR(36) NOT NULL COMMENT '생성자',
    `updated_at` DATETIME(6) NULL COMMENT '수정 시각',
    `updated_by` CHAR(36) NULL COMMENT '수정자',
    `version` INT NOT NULL DEFAULT 0 COMMENT '버전(낙관적 잠금)',
    PRIMARY KEY (`id`),
    CONSTRAINT `fk_equipment_product_id` FOREIGN KEY (`product_id`) REFERENCES `products` (`id`),
    CONSTRAINT `fk_equipment_current_location_id` FOREIGN KEY (`current_location_id`) REFERENCES `locations` (`id`),
    CONSTRAINT `fk_equipment_owner_partner_id` FOREIGN KEY (`owner_partner_id`) REFERENCES `partners` (`id`),
    CONSTRAINT `fk_equipment_project_id` FOREIGN KEY (`project_id`) REFERENCES `projects` (`id`),
    CONSTRAINT `fk_equipment_delivered_partner_id` FOREIGN KEY (`delivered_partner_id`) REFERENCES `partners` (`id`),
    CONSTRAINT `fk_equipment_replaced_by_equipment_id` FOREIGN KEY (`replaced_by_equipment_id`) REFERENCES `equipment` (`id`),
    CONSTRAINT `ck_equipment_1` CHECK (serial_status IN ('CONFIRMED', 'UNKNOWN')),
    CONSTRAINT `ck_equipment_2` CHECK (status IN ('IN_STOCK', 'INSPECTION', 'DEFECTIVE', 'IN_REPAIR', 'ISSUED', 'DELIVERED', 'TEMP_INSTALLED', 'LOANED_OUT', 'LOST', 'REPLACED', 'DISPOSED', 'RETURNED_TO_SUPPLIER', 'TRANSFERRED_OUT', 'RECEIPT_CANCELLED')),
    CONSTRAINT `ck_equipment_3` CHECK (owner_type IN ('OWN', 'THIRD_PARTY')),
    CONSTRAINT `ck_equipment_4` CHECK ((owner_type = 'OWN' AND owner_partner_id IS NULL) OR (owner_type = 'THIRD_PARTY' AND owner_partner_id IS NOT NULL)),
    CONSTRAINT `ck_equipment_5` CHECK (serial_status = 'UNKNOWN' OR serial_no IS NOT NULL),
    CONSTRAINT `ck_equipment_6` CHECK (origin_type IN ('LEDGER', 'PRE_CUTOVER_DELIVERY'))
) COMMENT = '[equipment] 개별 장비(시리얼)';

CREATE TABLE `equipment_events` (
    `id` CHAR(36) NOT NULL DEFAULT (UUID()) COMMENT 'ID (UUID v7, 앱에서 생성. DB 기본값도 v7, PostgreSQL 18)',
    `equipment_id` CHAR(36) NOT NULL COMMENT '장비',
    `event_type` VARCHAR(30) NOT NULL COMMENT '이벤트 유형',
    `business_date` DATE NOT NULL COMMENT '업무 날짜',
    `from_status` VARCHAR(30) NULL COMMENT '이전 상태',
    `to_status` VARCHAR(30) NULL COMMENT '이후 상태',
    `from_location_id` CHAR(36) NULL COMMENT '출발 위치',
    `to_location_id` CHAR(36) NULL COMMENT '도착 위치',
    `old_value` TEXT NULL COMMENT '이전 값(시리얼 수정 등)',
    `new_value` TEXT NULL COMMENT '새 값(시리얼 수정 등)',
    `ledger_entry_id` CHAR(36) NULL COMMENT '원장 행',
    `source_type` VARCHAR(30) NULL COMMENT '출처 유형',
    `source_id` CHAR(36) NULL COMMENT '출처 ID',
    `note` TEXT NULL COMMENT '비고',
    `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '생성 시각',
    `created_by` CHAR(36) NOT NULL COMMENT '생성자',
    PRIMARY KEY (`id`),
    CONSTRAINT `fk_equipment_events_equipment_id` FOREIGN KEY (`equipment_id`) REFERENCES `equipment` (`id`),
    CONSTRAINT `fk_equipment_events_from_location_id` FOREIGN KEY (`from_location_id`) REFERENCES `locations` (`id`),
    CONSTRAINT `fk_equipment_events_to_location_id` FOREIGN KEY (`to_location_id`) REFERENCES `locations` (`id`),
    CONSTRAINT `fk_equipment_events_ledger_entry_id` FOREIGN KEY (`ledger_entry_id`) REFERENCES `ledger_entries` (`id`)
) COMMENT = '[equipment] 장비 이력';

CREATE TABLE `warranties` (
    `id` CHAR(36) NOT NULL DEFAULT (UUID()) COMMENT 'ID (UUID v7, 앱에서 생성. DB 기본값도 v7, PostgreSQL 18)',
    `equipment_id` CHAR(36) NOT NULL COMMENT '장비',
    `status` VARCHAR(20) NOT NULL DEFAULT 'UNKNOWN' COMMENT '확인 상태',
    `start_date` DATE NULL COMMENT '보증 시작일',
    `end_date` DATE NULL COMMENT '보증 만료일',
    `basis` VARCHAR(20) NULL COMMENT '시작 기준',
    `inherited_from_equipment_id` CHAR(36) NULL COMMENT '승계 원 장비',
    `note` TEXT NULL COMMENT '비고',
    `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '생성 시각',
    `created_by` CHAR(36) NOT NULL COMMENT '생성자',
    `updated_at` DATETIME(6) NULL COMMENT '수정 시각',
    `updated_by` CHAR(36) NULL COMMENT '수정자',
    `version` INT NOT NULL DEFAULT 0 COMMENT '버전(낙관적 잠금)',
    PRIMARY KEY (`id`),
    UNIQUE KEY `uq_warranties_equipment_id` (`equipment_id`),
    CONSTRAINT `fk_warranties_equipment_id` FOREIGN KEY (`equipment_id`) REFERENCES `equipment` (`id`),
    CONSTRAINT `fk_warranties_inherited_from_equipment_id` FOREIGN KEY (`inherited_from_equipment_id`) REFERENCES `equipment` (`id`),
    CONSTRAINT `ck_warranties_1` CHECK (status IN ('CONFIRMED', 'UNKNOWN')),
    CONSTRAINT `ck_warranties_2` CHECK (end_date IS NULL OR start_date IS NULL OR end_date >= start_date),
    CONSTRAINT `ck_warranties_3` CHECK (basis IS NULL OR basis IN ('DELIVERY', 'MANUFACTURER', 'PURCHASE', 'MANUAL'))
) COMMENT = '[equipment] 보증';

CREATE TABLE `warranty_changes` (
    `id` CHAR(36) NOT NULL DEFAULT (UUID()) COMMENT 'ID (UUID v7, 앱에서 생성. DB 기본값도 v7, PostgreSQL 18)',
    `warranty_id` CHAR(36) NOT NULL COMMENT '보증',
    `old_start_date` DATE NULL COMMENT '이전 시작일',
    `old_end_date` DATE NULL COMMENT '이전 만료일',
    `new_start_date` DATE NULL COMMENT '변경 시작일',
    `new_end_date` DATE NULL COMMENT '변경 만료일',
    `reason` TEXT NULL COMMENT '사유',
    `changed_by` CHAR(36) NOT NULL COMMENT '변경자',
    `changed_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '변경 시각',
    PRIMARY KEY (`id`),
    CONSTRAINT `fk_warranty_changes_warranty_id` FOREIGN KEY (`warranty_id`) REFERENCES `warranties` (`id`)
) COMMENT = '[equipment] 보증 변경 이력';

CREATE TABLE `projects` (
    `id` CHAR(36) NOT NULL DEFAULT (UUID()) COMMENT 'ID (UUID v7, 앱에서 생성. DB 기본값도 v7, PostgreSQL 18)',
    `project_code` VARCHAR(30) NOT NULL COMMENT '프로젝트 코드',
    `project_name` VARCHAR(200) NOT NULL COMMENT '프로젝트명',
    `customer_partner_id` CHAR(36) NULL COMMENT '주 고객사',
    `status` VARCHAR(20) NOT NULL DEFAULT 'ACTIVE' COMMENT '상태',
    `note` TEXT NULL COMMENT '비고',
    `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '생성 시각',
    `created_by` CHAR(36) NOT NULL COMMENT '생성자',
    `updated_at` DATETIME(6) NULL COMMENT '수정 시각',
    `updated_by` CHAR(36) NULL COMMENT '수정자',
    `version` INT NOT NULL DEFAULT 0 COMMENT '버전(낙관적 잠금)',
    `deleted_at` DATETIME(6) NULL COMMENT '삭제 시각',
    `deleted_by` CHAR(36) NULL COMMENT '삭제자',
    PRIMARY KEY (`id`),
    UNIQUE KEY `uq_projects_project_code` (`project_code`),
    CONSTRAINT `fk_projects_customer_partner_id` FOREIGN KEY (`customer_partner_id`) REFERENCES `partners` (`id`),
    CONSTRAINT `ck_projects_1` CHECK (status IN ('ACTIVE', 'COMPLETED', 'CANCELLED'))
) COMMENT = '[project] 프로젝트';

CREATE TABLE `trade_documents` (
    `id` CHAR(36) NOT NULL DEFAULT (UUID()) COMMENT 'ID (UUID v7, 앱에서 생성. DB 기본값도 v7, PostgreSQL 18)',
    `project_id` CHAR(36) NOT NULL COMMENT '프로젝트',
    `trade_type` VARCHAR(20) NOT NULL COMMENT '거래 구분',
    `partner_id` CHAR(36) NOT NULL COMMENT '거래처',
    `document_no` VARCHAR(50) NULL COMMENT '거래처 문서번호',
    `document_date` DATE NOT NULL COMMENT '문서 일자',
    `status` VARCHAR(20) NOT NULL DEFAULT 'DRAFT' COMMENT '상태',
    `copied_from_document_id` CHAR(36) NULL COMMENT '복사 원본 문서',
    `note` TEXT NULL COMMENT '비고',
    `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '생성 시각',
    `created_by` CHAR(36) NOT NULL COMMENT '생성자',
    `updated_at` DATETIME(6) NULL COMMENT '수정 시각',
    `updated_by` CHAR(36) NULL COMMENT '수정자',
    `version` INT NOT NULL DEFAULT 0 COMMENT '버전(낙관적 잠금)',
    `deleted_at` DATETIME(6) NULL COMMENT '삭제 시각',
    `deleted_by` CHAR(36) NULL COMMENT '삭제자',
    PRIMARY KEY (`id`),
    CONSTRAINT `fk_trade_documents_project_id` FOREIGN KEY (`project_id`) REFERENCES `projects` (`id`),
    CONSTRAINT `fk_trade_documents_partner_id` FOREIGN KEY (`partner_id`) REFERENCES `partners` (`id`),
    CONSTRAINT `fk_trade_documents_copied_from_document_id` FOREIGN KEY (`copied_from_document_id`) REFERENCES `trade_documents` (`id`),
    CONSTRAINT `ck_trade_documents_1` CHECK (trade_type IN ('PURCHASE', 'SALES', 'PRE_ORDER')),
    CONSTRAINT `ck_trade_documents_2` CHECK (status IN ('DRAFT', 'CONFIRMED', 'COMPLETED', 'CANCELLED'))
) COMMENT = '[project] 거래 문서(발주서·매출·선발주)';

CREATE TABLE `trade_lines` (
    `id` CHAR(36) NOT NULL DEFAULT (UUID()) COMMENT 'ID (UUID v7, 앱에서 생성. DB 기본값도 v7, PostgreSQL 18)',
    `document_id` CHAR(36) NOT NULL COMMENT '거래 문서',
    `line_no` INT NOT NULL COMMENT '행 번호',
    `product_id` CHAR(36) NOT NULL COMMENT '제품',
    `quantity` INT NOT NULL COMMENT '문서 수량',
    `opening_fulfilled_quantity` INT NOT NULL DEFAULT 0 COMMENT '기준일 이전 처리 수량',
    `fulfilled_quantity` INT NOT NULL DEFAULT 0 COMMENT '처리된 수량',
    `closed_quantity` INT NOT NULL DEFAULT 0 COMMENT '잔량 마감 수량',
    `closed_reason` TEXT NULL COMMENT '잔량 마감 사유',
    `closed_by` CHAR(36) NULL COMMENT '잔량 마감자',
    `closed_at` DATETIME(6) NULL COMMENT '잔량 마감 시각',
    `route` VARCHAR(20) NOT NULL DEFAULT 'WAREHOUSE' COMMENT '경로(창고 경유/직납)',
    `note` TEXT NULL COMMENT '비고',
    `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '생성 시각',
    `created_by` CHAR(36) NOT NULL COMMENT '생성자',
    `updated_at` DATETIME(6) NULL COMMENT '수정 시각',
    `updated_by` CHAR(36) NULL COMMENT '수정자',
    `version` INT NOT NULL DEFAULT 0 COMMENT '버전(낙관적 잠금)',
    PRIMARY KEY (`id`),
    UNIQUE KEY `uq_trade_lines_document_id_line_no` (`document_id`, `line_no`),
    CONSTRAINT `fk_trade_lines_document_id` FOREIGN KEY (`document_id`) REFERENCES `trade_documents` (`id`),
    CONSTRAINT `fk_trade_lines_product_id` FOREIGN KEY (`product_id`) REFERENCES `products` (`id`),
    CONSTRAINT `ck_trade_lines_1` CHECK (quantity > 0),
    CONSTRAINT `ck_trade_lines_2` CHECK (fulfilled_quantity >= 0),
    CONSTRAINT `ck_trade_lines_3` CHECK (closed_quantity >= 0),
    CONSTRAINT `ck_trade_lines_4` CHECK (opening_fulfilled_quantity + fulfilled_quantity + closed_quantity <= quantity),
    CONSTRAINT `ck_trade_lines_5` CHECK (route IN ('WAREHOUSE', 'DIRECT')),
    CONSTRAINT `ck_trade_lines_6` CHECK (opening_fulfilled_quantity >= 0)
) COMMENT = '[project] 거래 품목';

CREATE TABLE `trade_document_changes` (
    `id` CHAR(36) NOT NULL DEFAULT (UUID()) COMMENT 'ID (UUID v7, 앱에서 생성. DB 기본값도 v7, PostgreSQL 18)',
    `document_id` CHAR(36) NOT NULL COMMENT '거래 문서',
    `line_id` CHAR(36) NULL COMMENT '거래 품목',
    `field_name` VARCHAR(50) NOT NULL COMMENT '변경 항목',
    `old_value` TEXT NULL COMMENT '이전 값',
    `new_value` TEXT NULL COMMENT '새 값',
    `reason` TEXT NULL COMMENT '사유',
    `changed_by` CHAR(36) NOT NULL COMMENT '변경자',
    `changed_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '변경 시각',
    PRIMARY KEY (`id`),
    CONSTRAINT `fk_trade_document_changes_document_id` FOREIGN KEY (`document_id`) REFERENCES `trade_documents` (`id`),
    CONSTRAINT `fk_trade_document_changes_line_id` FOREIGN KEY (`line_id`) REFERENCES `trade_lines` (`id`)
) COMMENT = '[project] 거래 문서 변경 이력';

CREATE TABLE `allocations` (
    `id` CHAR(36) NOT NULL DEFAULT (UUID()) COMMENT 'ID (UUID v7, 앱에서 생성. DB 기본값도 v7, PostgreSQL 18)',
    `product_id` CHAR(36) NOT NULL COMMENT '제품',
    `quantity` INT NOT NULL COMMENT '배정 수량',
    `consumed_quantity` INT NOT NULL DEFAULT 0 COMMENT '소진 수량',
    `target_type` VARCHAR(20) NOT NULL COMMENT '배정 대상 유형',
    `project_id` CHAR(36) NULL COMMENT '대상 프로젝트',
    `loan_document_id` CHAR(36) NULL COMMENT '대상 차입(상환용)',
    `source_type` VARCHAR(20) NOT NULL COMMENT '배정 원천(보유/예정)',
    `source_trade_line_id` CHAR(36) NULL COMMENT '예정 물량 발주 품목',
    `owner_type` VARCHAR(20) NULL COMMENT '보유 재고 소유 구분',
    `owner_partner_id` CHAR(36) NULL COMMENT '타사 소유 업체',
    `equipment_id` CHAR(36) NULL COMMENT '개별 장비',
    `status` VARCHAR(20) NOT NULL DEFAULT 'ACTIVE' COMMENT '상태',
    `note` TEXT NULL COMMENT '비고',
    `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '생성 시각',
    `created_by` CHAR(36) NOT NULL COMMENT '생성자',
    `updated_at` DATETIME(6) NULL COMMENT '수정 시각',
    `updated_by` CHAR(36) NULL COMMENT '수정자',
    `version` INT NOT NULL DEFAULT 0 COMMENT '버전(낙관적 잠금)',
    PRIMARY KEY (`id`),
    CONSTRAINT `fk_allocations_product_id` FOREIGN KEY (`product_id`) REFERENCES `products` (`id`),
    CONSTRAINT `fk_allocations_project_id` FOREIGN KEY (`project_id`) REFERENCES `projects` (`id`),
    CONSTRAINT `fk_allocations_loan_document_id` FOREIGN KEY (`loan_document_id`) REFERENCES `loan_documents` (`id`),
    CONSTRAINT `fk_allocations_source_trade_line_id` FOREIGN KEY (`source_trade_line_id`) REFERENCES `trade_lines` (`id`),
    CONSTRAINT `fk_allocations_owner_partner_id` FOREIGN KEY (`owner_partner_id`) REFERENCES `partners` (`id`),
    CONSTRAINT `fk_allocations_equipment_id` FOREIGN KEY (`equipment_id`) REFERENCES `equipment` (`id`),
    CONSTRAINT `ck_allocations_1` CHECK (quantity > 0),
    CONSTRAINT `ck_allocations_2` CHECK (consumed_quantity >= 0 AND consumed_quantity <= quantity),
    CONSTRAINT `ck_allocations_3` CHECK (target_type IN ('PROJECT', 'LOAN_REPAY')),
    CONSTRAINT `ck_allocations_4` CHECK ((target_type = 'PROJECT' AND project_id IS NOT NULL) OR (target_type = 'LOAN_REPAY' AND loan_document_id IS NOT NULL)),
    CONSTRAINT `ck_allocations_5` CHECK (source_type IN ('STOCK', 'RECEIVED', 'PLANNED')),
    CONSTRAINT `ck_allocations_6` CHECK (source_type = 'STOCK' OR source_trade_line_id IS NOT NULL),
    CONSTRAINT `ck_allocations_7` CHECK (owner_type IS NULL OR owner_type IN ('OWN', 'THIRD_PARTY')),
    CONSTRAINT `ck_allocations_8` CHECK (status IN ('ACTIVE', 'RELEASED', 'CONSUMED'))
) COMMENT = '[allocation] 배정';

CREATE TABLE `allocation_events` (
    `id` CHAR(36) NOT NULL DEFAULT (UUID()) COMMENT 'ID (UUID v7, 앱에서 생성. DB 기본값도 v7, PostgreSQL 18)',
    `allocation_id` CHAR(36) NOT NULL COMMENT '배정',
    `action` VARCHAR(20) NOT NULL COMMENT '동작',
    `quantity` INT NOT NULL COMMENT '수량',
    `reason` TEXT NULL COMMENT '사유',
    `acted_by` CHAR(36) NOT NULL COMMENT '처리자',
    `acted_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '처리 시각',
    PRIMARY KEY (`id`),
    CONSTRAINT `fk_allocation_events_allocation_id` FOREIGN KEY (`allocation_id`) REFERENCES `allocations` (`id`),
    CONSTRAINT `ck_allocation_events_1` CHECK (action IN ('ALLOCATE', 'CHANGE', 'RELEASE', 'CONSUME', 'CONVERT'))
) COMMENT = '[allocation] 배정 이력';

CREATE TABLE `deliveries` (
    `id` CHAR(36) NOT NULL DEFAULT (UUID()) COMMENT 'ID (UUID v7, 앱에서 생성. DB 기본값도 v7, PostgreSQL 18)',
    `delivery_no` VARCHAR(30) NOT NULL COMMENT '납품 번호',
    `project_id` CHAR(36) NOT NULL COMMENT '프로젝트',
    `sales_document_id` CHAR(36) NULL COMMENT '매출 문서',
    `customer_partner_id` CHAR(36) NOT NULL COMMENT '고객사',
    `delivery_date` DATE NOT NULL COMMENT '납품일',
    `place` VARCHAR(300) NULL COMMENT '납품 장소',
    `route` VARCHAR(20) NOT NULL DEFAULT 'WAREHOUSE' COMMENT '경로(창고 경유/직납)',
    `bundle_id` CHAR(36) NULL COMMENT '구성 묶음',
    `bundle_set_quantity` INT NULL COMMENT '세트 수',
    `status` VARCHAR(20) NOT NULL DEFAULT 'DRAFT' COMMENT '상태',
    `transaction_id` CHAR(36) NULL COMMENT '창고 출고 묶음',
    `note` TEXT NULL COMMENT '비고',
    `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '생성 시각',
    `created_by` CHAR(36) NOT NULL COMMENT '생성자',
    `updated_at` DATETIME(6) NULL COMMENT '수정 시각',
    `updated_by` CHAR(36) NULL COMMENT '수정자',
    `version` INT NOT NULL DEFAULT 0 COMMENT '버전(낙관적 잠금)',
    PRIMARY KEY (`id`),
    UNIQUE KEY `uq_deliveries_delivery_no` (`delivery_no`),
    CONSTRAINT `fk_deliveries_project_id` FOREIGN KEY (`project_id`) REFERENCES `projects` (`id`),
    CONSTRAINT `fk_deliveries_sales_document_id` FOREIGN KEY (`sales_document_id`) REFERENCES `trade_documents` (`id`),
    CONSTRAINT `fk_deliveries_customer_partner_id` FOREIGN KEY (`customer_partner_id`) REFERENCES `partners` (`id`),
    CONSTRAINT `fk_deliveries_bundle_id` FOREIGN KEY (`bundle_id`) REFERENCES `bundles` (`id`),
    CONSTRAINT `fk_deliveries_transaction_id` FOREIGN KEY (`transaction_id`) REFERENCES `stock_transactions` (`id`),
    CONSTRAINT `ck_deliveries_1` CHECK (route IN ('WAREHOUSE', 'DIRECT')),
    CONSTRAINT `ck_deliveries_2` CHECK (status IN ('DRAFT', 'POSTED', 'CANCELLED')),
    CONSTRAINT `ck_deliveries_3` CHECK ((bundle_id IS NULL AND bundle_set_quantity IS NULL) OR (bundle_id IS NOT NULL AND bundle_set_quantity > 0))
) COMMENT = '[delivery] 납품 회차';

CREATE TABLE `delivery_lines` (
    `id` CHAR(36) NOT NULL DEFAULT (UUID()) COMMENT 'ID (UUID v7, 앱에서 생성. DB 기본값도 v7, PostgreSQL 18)',
    `delivery_id` CHAR(36) NOT NULL COMMENT '납품 회차',
    `line_no` INT NOT NULL COMMENT '행 번호',
    `product_id` CHAR(36) NOT NULL COMMENT '제품',
    `quantity` INT NOT NULL COMMENT '납품 수량',
    `sales_line_id` CHAR(36) NULL COMMENT '매출 품목',
    `purchase_line_id` CHAR(36) NULL COMMENT '직납 발주 품목',
    `loan_line_id` CHAR(36) NULL COMMENT '차입 직납 대차 품목',
    `equipment_id` CHAR(36) NULL COMMENT '개별 장비',
    `returned_quantity` INT NOT NULL DEFAULT 0 COMMENT '반품 수량',
    `note` TEXT NULL COMMENT '비고',
    PRIMARY KEY (`id`),
    UNIQUE KEY `uq_delivery_lines_delivery_id_line_no` (`delivery_id`, `line_no`),
    CONSTRAINT `fk_delivery_lines_delivery_id` FOREIGN KEY (`delivery_id`) REFERENCES `deliveries` (`id`),
    CONSTRAINT `fk_delivery_lines_product_id` FOREIGN KEY (`product_id`) REFERENCES `products` (`id`),
    CONSTRAINT `fk_delivery_lines_sales_line_id` FOREIGN KEY (`sales_line_id`) REFERENCES `trade_lines` (`id`),
    CONSTRAINT `fk_delivery_lines_purchase_line_id` FOREIGN KEY (`purchase_line_id`) REFERENCES `trade_lines` (`id`),
    CONSTRAINT `fk_delivery_lines_loan_line_id` FOREIGN KEY (`loan_line_id`) REFERENCES `loan_lines` (`id`),
    CONSTRAINT `fk_delivery_lines_equipment_id` FOREIGN KEY (`equipment_id`) REFERENCES `equipment` (`id`),
    CONSTRAINT `ck_delivery_lines_1` CHECK (quantity > 0),
    CONSTRAINT `ck_delivery_lines_2` CHECK (returned_quantity >= 0 AND returned_quantity <= quantity)
) COMMENT = '[delivery] 납품 품목';

CREATE TABLE `delivery_returns` (
    `id` CHAR(36) NOT NULL DEFAULT (UUID()) COMMENT 'ID (UUID v7, 앱에서 생성. DB 기본값도 v7, PostgreSQL 18)',
    `delivery_line_id` CHAR(36) NULL COMMENT '납품 품목',
    `equipment_id` CHAR(36) NULL COMMENT '기준일 이전 납품 장비',
    `quantity` INT NOT NULL COMMENT '반품 수량',
    `return_date` DATE NOT NULL COMMENT '반품일',
    `transaction_id` CHAR(36) NULL COMMENT '반품 입고 묶음',
    `reason` TEXT NULL COMMENT '사유',
    `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '생성 시각',
    `created_by` CHAR(36) NOT NULL COMMENT '생성자',
    `updated_at` DATETIME(6) NULL COMMENT '수정 시각',
    `updated_by` CHAR(36) NULL COMMENT '수정자',
    `version` INT NOT NULL DEFAULT 0 COMMENT '버전(낙관적 잠금)',
    PRIMARY KEY (`id`),
    CONSTRAINT `fk_delivery_returns_delivery_line_id` FOREIGN KEY (`delivery_line_id`) REFERENCES `delivery_lines` (`id`),
    CONSTRAINT `fk_delivery_returns_equipment_id` FOREIGN KEY (`equipment_id`) REFERENCES `equipment` (`id`),
    CONSTRAINT `fk_delivery_returns_transaction_id` FOREIGN KEY (`transaction_id`) REFERENCES `stock_transactions` (`id`),
    CONSTRAINT `ck_delivery_returns_1` CHECK (quantity > 0),
    CONSTRAINT `ck_delivery_returns_2` CHECK (delivery_line_id IS NOT NULL OR (equipment_id IS NOT NULL AND quantity = 1))
) COMMENT = '[delivery] 고객 반품';

CREATE TABLE `loan_documents` (
    `id` CHAR(36) NOT NULL DEFAULT (UUID()) COMMENT 'ID (UUID v7, 앱에서 생성. DB 기본값도 v7, PostgreSQL 18)',
    `loan_no` VARCHAR(30) NOT NULL COMMENT '대차 번호',
    `direction` VARCHAR(10) NOT NULL COMMENT '방향(차입/대여)',
    `partner_id` CHAR(36) NOT NULL COMMENT '상대 업체',
    `project_id` CHAR(36) NULL COMMENT '관련 프로젝트',
    `settlement_method` VARCHAR(20) NOT NULL COMMENT '정산 방식',
    `due_date` DATE NULL COMMENT '상환·회수 기한',
    `status` VARCHAR(20) NOT NULL DEFAULT 'OPEN' COMMENT '상태',
    `converted_trade_document_id` CHAR(36) NULL COMMENT '전환 거래 문서',
    `approved_by` CHAR(36) NULL COMMENT '승인자',
    `approved_at` DATETIME(6) NULL COMMENT '승인 시각',
    `note` TEXT NULL COMMENT '비고',
    `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '생성 시각',
    `created_by` CHAR(36) NOT NULL COMMENT '생성자',
    `updated_at` DATETIME(6) NULL COMMENT '수정 시각',
    `updated_by` CHAR(36) NULL COMMENT '수정자',
    `version` INT NOT NULL DEFAULT 0 COMMENT '버전(낙관적 잠금)',
    `deleted_at` DATETIME(6) NULL COMMENT '삭제 시각',
    `deleted_by` CHAR(36) NULL COMMENT '삭제자',
    PRIMARY KEY (`id`),
    UNIQUE KEY `uq_loan_documents_loan_no` (`loan_no`),
    CONSTRAINT `fk_loan_documents_partner_id` FOREIGN KEY (`partner_id`) REFERENCES `partners` (`id`),
    CONSTRAINT `fk_loan_documents_project_id` FOREIGN KEY (`project_id`) REFERENCES `projects` (`id`),
    CONSTRAINT `fk_loan_documents_converted_trade_document_id` FOREIGN KEY (`converted_trade_document_id`) REFERENCES `trade_documents` (`id`),
    CONSTRAINT `ck_loan_documents_1` CHECK (direction IN ('IN', 'OUT')),
    CONSTRAINT `ck_loan_documents_2` CHECK (settlement_method IN ('IN_KIND', 'CONVERT', 'RETURN_ORIGINAL')),
    CONSTRAINT `ck_loan_documents_3` CHECK (status IN ('OPEN', 'SETTLED', 'CANCELLED'))
) COMMENT = '[loan] 대차 문서(차입·대여)';

CREATE TABLE `loan_lines` (
    `id` CHAR(36) NOT NULL DEFAULT (UUID()) COMMENT 'ID (UUID v7, 앱에서 생성. DB 기본값도 v7, PostgreSQL 18)',
    `loan_id` CHAR(36) NOT NULL COMMENT '대차 문서',
    `line_no` INT NOT NULL COMMENT '행 번호',
    `product_id` CHAR(36) NOT NULL COMMENT '제품',
    `quantity` INT NOT NULL COMMENT '수량',
    `moved_quantity` INT NOT NULL DEFAULT 0 COMMENT '받은(차입)·내보낸(대여) 수량',
    `settled_quantity` INT NOT NULL DEFAULT 0 COMMENT '정산 수량',
    `equipment_id` CHAR(36) NULL COMMENT '개별 장비',
    `note` TEXT NULL COMMENT '비고',
    PRIMARY KEY (`id`),
    UNIQUE KEY `uq_loan_lines_loan_id_line_no` (`loan_id`, `line_no`),
    CONSTRAINT `fk_loan_lines_loan_id` FOREIGN KEY (`loan_id`) REFERENCES `loan_documents` (`id`),
    CONSTRAINT `fk_loan_lines_product_id` FOREIGN KEY (`product_id`) REFERENCES `products` (`id`),
    CONSTRAINT `fk_loan_lines_equipment_id` FOREIGN KEY (`equipment_id`) REFERENCES `equipment` (`id`),
    CONSTRAINT `ck_loan_lines_1` CHECK (quantity > 0),
    CONSTRAINT `ck_loan_lines_2` CHECK (settled_quantity >= 0 AND settled_quantity <= quantity),
    CONSTRAINT `ck_loan_lines_3` CHECK (moved_quantity >= 0 AND moved_quantity <= quantity)
) COMMENT = '[loan] 대차 품목';

CREATE TABLE `loan_settlements` (
    `id` CHAR(36) NOT NULL DEFAULT (UUID()) COMMENT 'ID (UUID v7, 앱에서 생성. DB 기본값도 v7, PostgreSQL 18)',
    `loan_line_id` CHAR(36) NOT NULL COMMENT '대차 품목',
    `settled_date` DATE NOT NULL COMMENT '정산 날짜',
    `method` VARCHAR(20) NOT NULL COMMENT '정산 방식',
    `quantity` INT NOT NULL COMMENT '정산 수량',
    `settled_product_id` CHAR(36) NOT NULL COMMENT '실제 주고받은 제품',
    `equipment_id` CHAR(36) NULL COMMENT '개별 장비',
    `status` VARCHAR(20) NOT NULL DEFAULT 'POSTED' COMMENT '상태',
    `transaction_id` CHAR(36) NULL COMMENT '처리 묶음',
    `trade_document_id` CHAR(36) NULL COMMENT '전환 거래 문서',
    `note` TEXT NULL COMMENT '비고',
    `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '생성 시각',
    `created_by` CHAR(36) NOT NULL COMMENT '생성자',
    `updated_at` DATETIME(6) NULL COMMENT '수정 시각',
    `updated_by` CHAR(36) NULL COMMENT '수정자',
    `version` INT NOT NULL DEFAULT 0 COMMENT '버전(낙관적 잠금)',
    PRIMARY KEY (`id`),
    CONSTRAINT `fk_loan_settlements_loan_line_id` FOREIGN KEY (`loan_line_id`) REFERENCES `loan_lines` (`id`),
    CONSTRAINT `fk_loan_settlements_settled_product_id` FOREIGN KEY (`settled_product_id`) REFERENCES `products` (`id`),
    CONSTRAINT `fk_loan_settlements_equipment_id` FOREIGN KEY (`equipment_id`) REFERENCES `equipment` (`id`),
    CONSTRAINT `fk_loan_settlements_transaction_id` FOREIGN KEY (`transaction_id`) REFERENCES `stock_transactions` (`id`),
    CONSTRAINT `fk_loan_settlements_trade_document_id` FOREIGN KEY (`trade_document_id`) REFERENCES `trade_documents` (`id`),
    CONSTRAINT `ck_loan_settlements_1` CHECK (quantity > 0),
    CONSTRAINT `ck_loan_settlements_2` CHECK (method IN ('IN_KIND', 'CONVERT', 'RETURN_ORIGINAL')),
    CONSTRAINT `ck_loan_settlements_3` CHECK (status IN ('PENDING_APPROVAL', 'POSTED', 'REJECTED', 'CANCELLED')),
    CONSTRAINT `ck_loan_settlements_4` CHECK (method <> 'CONVERT' OR trade_document_id IS NOT NULL),
    CONSTRAINT `ck_loan_settlements_5` CHECK (equipment_id IS NULL OR quantity = 1)
) COMMENT = '[loan] 대차 정산 기록';

CREATE TABLE `loan_document_changes` (
    `id` CHAR(36) NOT NULL DEFAULT (UUID()) COMMENT 'ID (UUID v7, 앱에서 생성. DB 기본값도 v7, PostgreSQL 18)',
    `loan_id` CHAR(36) NOT NULL COMMENT '대차 문서',
    `line_id` CHAR(36) NULL COMMENT '대차 품목',
    `field_name` VARCHAR(50) NOT NULL COMMENT '변경 항목',
    `old_value` TEXT NULL COMMENT '이전 값',
    `new_value` TEXT NULL COMMENT '새 값',
    `reason` TEXT NULL COMMENT '사유',
    `changed_by` CHAR(36) NOT NULL COMMENT '변경자',
    `changed_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '변경 시각',
    PRIMARY KEY (`id`),
    CONSTRAINT `fk_loan_document_changes_loan_id` FOREIGN KEY (`loan_id`) REFERENCES `loan_documents` (`id`),
    CONSTRAINT `fk_loan_document_changes_line_id` FOREIGN KEY (`line_id`) REFERENCES `loan_lines` (`id`)
) COMMENT = '[loan] 대차 문서 변경 이력';

CREATE TABLE `trash_events` (
    `id` CHAR(36) NOT NULL DEFAULT (UUID()) COMMENT 'ID (UUID v7, 앱에서 생성. DB 기본값도 v7, PostgreSQL 18)',
    `entity_type` VARCHAR(50) NOT NULL COMMENT '대상 유형',
    `entity_id` CHAR(36) NOT NULL COMMENT '대상 ID',
    `action` VARCHAR(10) NOT NULL COMMENT '동작(삭제/복구)',
    `reason` TEXT NULL COMMENT '사유',
    `acted_by` CHAR(36) NOT NULL COMMENT '처리자',
    `acted_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '처리 시각',
    PRIMARY KEY (`id`),
    CONSTRAINT `ck_trash_events_1` CHECK (action IN ('DELETE', 'RESTORE'))
) COMMENT = '[trash] 삭제·복구 이력';

CREATE TABLE `currencies` (
    `code` CHAR(3) NOT NULL COMMENT '통화 코드(ISO 4217)',
    `name` VARCHAR(50) NOT NULL COMMENT '통화명',
    `minor_unit` SMALLINT NOT NULL COMMENT '소수 자리수',
    `is_active` BOOLEAN NOT NULL DEFAULT FALSE COMMENT '사용 여부',
    PRIMARY KEY (`code`),
    CONSTRAINT `ck_currencies_1` CHECK (minor_unit BETWEEN 0 AND 4)
) COMMENT = '[cost] 통화';

CREATE TABLE `line_prices` (
    `trade_line_id` CHAR(36) NOT NULL COMMENT '거래 품목',
    `unit_price` NUMERIC(19,4) NOT NULL COMMENT '단가',
    `currency` CHAR(3) NOT NULL DEFAULT 'KRW' COMMENT '통화',
    `exchange_rate` NUMERIC(18,6) NOT NULL DEFAULT 1 COMMENT '적용 환율',
    `exchange_rate_date` DATE NULL COMMENT '환율 기준일',
    `unit_price_krw` NUMERIC(19,4) NOT NULL COMMENT '원화 환산',
    `tax_type` VARCHAR(20) NULL COMMENT '과세 구분',
    `attribution_basis` VARCHAR(20) NOT NULL DEFAULT 'DOCUMENT_DATE' COMMENT '금액 귀속 기준',
    `attribution_date` DATE NULL COMMENT '직접 입력한 귀속일(MANUAL일 때)',
    `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '생성 시각',
    `created_by` CHAR(36) NOT NULL COMMENT '생성자',
    `updated_at` DATETIME(6) NULL COMMENT '수정 시각',
    `updated_by` CHAR(36) NULL COMMENT '수정자',
    `version` INT NOT NULL DEFAULT 0 COMMENT '버전(낙관적 잠금)',
    PRIMARY KEY (`trade_line_id`),
    CONSTRAINT `fk_line_prices_trade_line_id` FOREIGN KEY (`trade_line_id`) REFERENCES `trade_lines` (`id`),
    CONSTRAINT `fk_line_prices_currency` FOREIGN KEY (`currency`) REFERENCES `currencies` (`code`),
    CONSTRAINT `ck_line_prices_1` CHECK (exchange_rate > 0),
    CONSTRAINT `ck_line_prices_2` CHECK (currency = 'KRW' OR exchange_rate_date IS NOT NULL),
    CONSTRAINT `ck_line_prices_3` CHECK (attribution_basis IN ('DOCUMENT_DATE', 'FULFILLED_DATE', 'MANUAL')),
    CONSTRAINT `ck_line_prices_4` CHECK ((attribution_basis = 'MANUAL') = (attribution_date IS NOT NULL))
) COMMENT = '[cost] 거래 품목 단가';

CREATE TABLE `extra_costs` (
    `id` CHAR(36) NOT NULL DEFAULT (UUID()) COMMENT 'ID (UUID v7, 앱에서 생성. DB 기본값도 v7, PostgreSQL 18)',
    `project_id` CHAR(36) NOT NULL COMMENT '프로젝트',
    `cost_type` VARCHAR(20) NOT NULL COMMENT '비용 유형',
    `amount` NUMERIC(20,4) NOT NULL COMMENT '금액',
    `currency` CHAR(3) NOT NULL DEFAULT 'KRW' COMMENT '통화',
    `exchange_rate` NUMERIC(18,6) NOT NULL DEFAULT 1 COMMENT '적용 환율',
    `exchange_rate_date` DATE NULL COMMENT '환율 기준일',
    `amount_krw` NUMERIC(18,2) NOT NULL COMMENT '원화 환산',
    `cost_date` DATE NOT NULL COMMENT '비용 발생일',
    `trade_document_id` CHAR(36) NULL COMMENT '관련 거래 문서',
    `loan_document_id` CHAR(36) NULL COMMENT '관련 대차 문서',
    `note` TEXT NULL COMMENT '비고',
    `attribution_basis` VARCHAR(20) NOT NULL DEFAULT 'COST_DATE' COMMENT '금액 귀속 기준',
    `attribution_date` DATE NULL COMMENT '직접 입력한 귀속일(MANUAL일 때)',
    `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '생성 시각',
    `created_by` CHAR(36) NOT NULL COMMENT '생성자',
    `updated_at` DATETIME(6) NULL COMMENT '수정 시각',
    `updated_by` CHAR(36) NULL COMMENT '수정자',
    `version` INT NOT NULL DEFAULT 0 COMMENT '버전(낙관적 잠금)',
    `deleted_at` DATETIME(6) NULL COMMENT '삭제 시각',
    `deleted_by` CHAR(36) NULL COMMENT '삭제자',
    PRIMARY KEY (`id`),
    CONSTRAINT `fk_extra_costs_project_id` FOREIGN KEY (`project_id`) REFERENCES `projects` (`id`),
    CONSTRAINT `fk_extra_costs_currency` FOREIGN KEY (`currency`) REFERENCES `currencies` (`code`),
    CONSTRAINT `fk_extra_costs_trade_document_id` FOREIGN KEY (`trade_document_id`) REFERENCES `trade_documents` (`id`),
    CONSTRAINT `fk_extra_costs_loan_document_id` FOREIGN KEY (`loan_document_id`) REFERENCES `loan_documents` (`id`),
    CONSTRAINT `ck_extra_costs_1` CHECK (cost_type IN ('SHIPPING', 'INSTALL', 'RENTAL', 'OTHER')),
    CONSTRAINT `ck_extra_costs_2` CHECK (exchange_rate > 0),
    CONSTRAINT `ck_extra_costs_3` CHECK (cost_type <> 'RENTAL' OR loan_document_id IS NOT NULL),
    CONSTRAINT `ck_extra_costs_4` CHECK (currency = 'KRW' OR exchange_rate_date IS NOT NULL),
    CONSTRAINT `ck_extra_costs_5` CHECK (attribution_basis IN ('COST_DATE', 'MANUAL')),
    CONSTRAINT `ck_extra_costs_6` CHECK ((attribution_basis = 'MANUAL') = (attribution_date IS NOT NULL))
) COMMENT = '[cost] 부대비용';

CREATE TABLE `loan_fees` (
    `loan_document_id` CHAR(36) NOT NULL COMMENT '대차 문서',
    `amount` NUMERIC(20,4) NOT NULL COMMENT '금액',
    `currency` CHAR(3) NOT NULL DEFAULT 'KRW' COMMENT '통화',
    `exchange_rate` NUMERIC(18,6) NOT NULL DEFAULT 1 COMMENT '적용 환율',
    `exchange_rate_date` DATE NULL COMMENT '환율 기준일',
    `amount_krw` NUMERIC(18,2) NOT NULL COMMENT '원화 환산',
    `attribution_basis` VARCHAR(20) NOT NULL DEFAULT 'SETTLED_DATE' COMMENT '금액 귀속 기준',
    `attribution_date` DATE NULL COMMENT '직접 입력한 귀속일(MANUAL일 때)',
    `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '생성 시각',
    `created_by` CHAR(36) NOT NULL COMMENT '생성자',
    `updated_at` DATETIME(6) NULL COMMENT '수정 시각',
    `updated_by` CHAR(36) NULL COMMENT '수정자',
    `version` INT NOT NULL DEFAULT 0 COMMENT '버전(낙관적 잠금)',
    PRIMARY KEY (`loan_document_id`),
    CONSTRAINT `fk_loan_fees_loan_document_id` FOREIGN KEY (`loan_document_id`) REFERENCES `loan_documents` (`id`),
    CONSTRAINT `fk_loan_fees_currency` FOREIGN KEY (`currency`) REFERENCES `currencies` (`code`),
    CONSTRAINT `ck_loan_fees_1` CHECK (exchange_rate > 0),
    CONSTRAINT `ck_loan_fees_2` CHECK (currency = 'KRW' OR exchange_rate_date IS NOT NULL),
    CONSTRAINT `ck_loan_fees_3` CHECK (attribution_basis IN ('SETTLED_DATE', 'DUE_DATE', 'MANUAL')),
    CONSTRAINT `ck_loan_fees_4` CHECK ((attribution_basis = 'MANUAL') = (attribution_date IS NOT NULL))
) COMMENT = '[cost] 대여료';

CREATE TABLE `opening_costs` (
    `ledger_entry_id` CHAR(36) NOT NULL COMMENT '초기 재고 원장 행',
    `unit_cost` NUMERIC(19,4) NOT NULL COMMENT '단가',
    `currency` CHAR(3) NOT NULL DEFAULT 'KRW' COMMENT '통화',
    `exchange_rate` NUMERIC(18,6) NOT NULL DEFAULT 1 COMMENT '적용 환율',
    `exchange_rate_date` DATE NULL COMMENT '환율 기준일',
    `unit_cost_krw` NUMERIC(19,4) NOT NULL COMMENT '원화 환산',
    `note` TEXT NULL COMMENT '평가 근거',
    `attribution_basis` VARCHAR(20) NOT NULL DEFAULT 'CUTOVER_DATE' COMMENT '금액 귀속 기준',
    `attribution_date` DATE NULL COMMENT '직접 입력한 귀속일(MANUAL일 때)',
    `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '생성 시각',
    `created_by` CHAR(36) NOT NULL COMMENT '생성자',
    `updated_at` DATETIME(6) NULL COMMENT '수정 시각',
    `updated_by` CHAR(36) NULL COMMENT '수정자',
    `version` INT NOT NULL DEFAULT 0 COMMENT '버전(낙관적 잠금)',
    PRIMARY KEY (`ledger_entry_id`),
    CONSTRAINT `fk_opening_costs_ledger_entry_id` FOREIGN KEY (`ledger_entry_id`) REFERENCES `ledger_entries` (`id`),
    CONSTRAINT `fk_opening_costs_currency` FOREIGN KEY (`currency`) REFERENCES `currencies` (`code`),
    CONSTRAINT `ck_opening_costs_1` CHECK (unit_cost >= 0),
    CONSTRAINT `ck_opening_costs_2` CHECK (exchange_rate > 0),
    CONSTRAINT `ck_opening_costs_3` CHECK (currency = 'KRW' OR exchange_rate_date IS NOT NULL),
    CONSTRAINT `ck_opening_costs_4` CHECK (attribution_basis IN ('CUTOVER_DATE', 'MANUAL')),
    CONSTRAINT `ck_opening_costs_5` CHECK ((attribution_basis = 'MANUAL') = (attribution_date IS NOT NULL))
) COMMENT = '[cost] 초기 재고 단가';

CREATE TABLE `cost_changes` (
    `id` CHAR(36) NOT NULL DEFAULT (UUID()) COMMENT 'ID (UUID v7, 앱에서 생성. DB 기본값도 v7, PostgreSQL 18)',
    `target_type` VARCHAR(20) NOT NULL COMMENT '대상 유형',
    `target_id` CHAR(36) NOT NULL COMMENT '대상 ID(거래 품목·부대비용·대차 문서·원장 행)',
    `field_name` VARCHAR(50) NOT NULL COMMENT '바뀐 항목',
    `old_value` TEXT NULL COMMENT '이전 값',
    `new_value` TEXT NULL COMMENT '새 값',
    `reason` TEXT NULL COMMENT '사유',
    `changed_by` CHAR(36) NOT NULL COMMENT '변경자',
    `changed_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '변경 시각',
    PRIMARY KEY (`id`),
    CONSTRAINT `ck_cost_changes_1` CHECK (target_type IN ('LINE_PRICE', 'EXTRA_COST', 'LOAN_FEE', 'OPENING_COST'))
) COMMENT = '[cost] 금액 변경 이력';

CREATE TABLE `files` (
    `id` CHAR(36) NOT NULL DEFAULT (UUID()) COMMENT 'ID (UUID v7, 앱에서 생성. DB 기본값도 v7, PostgreSQL 18)',
    `target_type` VARCHAR(30) NOT NULL COMMENT '첨부 대상 종류',
    `target_id` CHAR(36) NOT NULL COMMENT '첨부 대상 ID',
    `original_name` VARCHAR(300) NOT NULL COMMENT '원본 파일명',
    `content_type` VARCHAR(100) NOT NULL COMMENT '파일 형식(MIME)',
    `storage_key` VARCHAR(500) NOT NULL COMMENT '저장 위치 키(최상위 폴더 기준 상대 경로)',
    `content_hash` VARCHAR(64) NOT NULL COMMENT '내용 해시(SHA-256, 같은 내용 경고용)',
    `size_bytes` BIGINT NOT NULL COMMENT '크기(바이트)',
    `uploaded_by` CHAR(36) NOT NULL COMMENT '올린 사람',
    `uploaded_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '올린 시각',
    `note` TEXT NULL COMMENT '비고',
    `deleted_at` DATETIME(6) NULL COMMENT '삭제 시각',
    `deleted_by` CHAR(36) NULL COMMENT '삭제자',
    PRIMARY KEY (`id`),
    UNIQUE KEY `uq_files_storage_key` (`storage_key`),
    CONSTRAINT `ck_files_1` CHECK (target_type IN ('TRADE_DOCUMENT')),
    CONSTRAINT `ck_files_2` CHECK (content_type IN ('application/pdf', 'image/jpeg', 'image/png')),
    CONSTRAINT `ck_files_3` CHECK (size_bytes > 0 AND size_bytes <= 20971520)
) COMMENT = '[importing] 첨부 파일(증빙)';

CREATE TABLE `idempotency_keys` (
    `idempotency_key` VARCHAR(64) NOT NULL COMMENT '중복 요청 키',
    `user_id` CHAR(36) NOT NULL COMMENT '요청자',
    `action` VARCHAR(100) NOT NULL COMMENT 'API 동작',
    `request_hash` VARCHAR(64) NOT NULL COMMENT '요청 내용 해시',
    `status` VARCHAR(20) NOT NULL DEFAULT 'IN_PROGRESS' COMMENT '처리 상태',
    `response_status` INT NULL COMMENT '처음 응답 HTTP 상태',
    `response_body` JSON NULL COMMENT '처음 응답 본문',
    `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '받은 시각',
    `completed_at` DATETIME(6) NULL COMMENT '끝난 시각',
    PRIMARY KEY (`idempotency_key`),
    CONSTRAINT `ck_idempotency_keys_1` CHECK (status IN ('IN_PROGRESS', 'DONE')),
    CONSTRAINT `ck_idempotency_keys_2` CHECK (status = 'IN_PROGRESS' OR (response_status IS NOT NULL AND completed_at IS NOT NULL))
) COMMENT = '[common] 중복 요청 키';

CREATE TABLE `review_requests` (
    `id` CHAR(36) NOT NULL DEFAULT (UUID()) COMMENT 'ID (UUID v7, 앱에서 생성. DB 기본값도 v7, PostgreSQL 18)',
    `request_type` VARCHAR(30) NOT NULL COMMENT '요청 종류',
    `target_type` VARCHAR(30) NOT NULL COMMENT '대상 유형',
    `target_id` CHAR(36) NOT NULL COMMENT '대상 ID',
    `status` VARCHAR(20) NOT NULL DEFAULT 'PENDING' COMMENT '상태',
    `summary` TEXT NULL COMMENT '요약',
    `requested_by` CHAR(36) NOT NULL COMMENT '요청자',
    `requested_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '요청 시각',
    `decided_by` CHAR(36) NULL COMMENT '처리자',
    `decided_at` DATETIME(6) NULL COMMENT '처리 시각',
    `decision_reason` TEXT NULL COMMENT '반려 사유',
    `version` INT NOT NULL DEFAULT 0 COMMENT '버전(낙관적 잠금)',
    PRIMARY KEY (`id`),
    CONSTRAINT `ck_review_requests_1` CHECK (request_type IN ('DISPOSAL', 'LOAN_OUT', 'EQUIVALENT_SETTLEMENT', 'COUNT_DIFFERENCE', 'UNPLANNED_RECEIPT', 'SERIAL_CHANGE', 'LOAN_DUE_CHANGE')),
    CONSTRAINT `ck_review_requests_2` CHECK (status IN ('PENDING', 'APPROVED', 'REJECTED', 'CONFIRMED')),
    CONSTRAINT `ck_review_requests_3` CHECK (status NOT IN ('APPROVED', 'REJECTED') OR request_type IN ('DISPOSAL', 'LOAN_OUT', 'EQUIVALENT_SETTLEMENT', 'COUNT_DIFFERENCE')),
    CONSTRAINT `ck_review_requests_4` CHECK (status <> 'CONFIRMED' OR request_type IN ('UNPLANNED_RECEIPT', 'SERIAL_CHANGE', 'LOAN_DUE_CHANGE')),
    CONSTRAINT `ck_review_requests_5` CHECK (status = 'PENDING' OR (decided_by IS NOT NULL AND decided_at IS NOT NULL)),
    CONSTRAINT `ck_review_requests_6` CHECK (status <> 'REJECTED' OR decision_reason IS NOT NULL)
) COMMENT = '[admin] 승인·확인 요청';

CREATE TABLE `notifications` (
    `id` CHAR(36) NOT NULL DEFAULT (UUID()) COMMENT 'ID (UUID v7, 앱에서 생성. DB 기본값도 v7, PostgreSQL 18)',
    `recipient_user_id` CHAR(36) NOT NULL COMMENT '받는 사람',
    `notification_type` VARCHAR(30) NOT NULL COMMENT '알림 종류',
    `title` VARCHAR(200) NOT NULL COMMENT '제목',
    `message` TEXT NULL COMMENT '내용',
    `target_type` VARCHAR(30) NULL COMMENT '연결 대상 유형',
    `target_id` CHAR(36) NULL COMMENT '연결 대상 ID',
    `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '생성 시각',
    `read_at` DATETIME(6) NULL COMMENT '읽은 시각',
    PRIMARY KEY (`id`),
    CONSTRAINT `ck_notifications_1` CHECK (notification_type IN ('REVIEW_REJECTED', 'INTEGRITY_ALERT', 'ALLOCATION_RELEASED', 'WARRANTY_EXPIRING'))
) COMMENT = '[admin] 알림';

CREATE TABLE `integrity_check_results` (
    `id` CHAR(36) NOT NULL DEFAULT (UUID()) COMMENT 'ID (UUID v7, 앱에서 생성. DB 기본값도 v7, PostgreSQL 18)',
    `check_code` VARCHAR(10) NOT NULL COMMENT '점검 항목(C1~)',
    `target_type` VARCHAR(30) NOT NULL COMMENT '어긋난 대상 유형',
    `target_key` VARCHAR(200) NOT NULL COMMENT '어긋난 대상 키',
    `detail` JSON NOT NULL COMMENT '어긋난 내용',
    `first_found_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '처음 발견 시각',
    `last_found_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '마지막 발견 시각',
    `resolved_at` DATETIME(6) NULL COMMENT '해결 확인 시각',
    PRIMARY KEY (`id`),
    CONSTRAINT `ck_integrity_check_results_1` CHECK (resolved_at IS NULL OR resolved_at >= first_found_at)
) COMMENT = '[admin] 정합성 점검 결과';

SET FOREIGN_KEY_CHECKS = 1;
