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
ALTER TABLE cost.line_prices  ADD CONSTRAINT ck_line_prices_krw_rate  CHECK (currency <> 'KRW' OR exchange_rate = 1);
ALTER TABLE cost.extra_costs  ADD CONSTRAINT ck_extra_costs_krw_rate  CHECK (currency <> 'KRW' OR exchange_rate = 1);
ALTER TABLE cost.loan_fees    ADD CONSTRAINT ck_loan_fees_krw_rate    CHECK (currency <> 'KRW' OR exchange_rate = 1);
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

-- P5 취소 행은 원본을 가리키되 자기 자신은 아님
ALTER TABLE inventory.ledger_entries
    ADD CONSTRAINT ck_ledger_entries_reversal_self CHECK (reversal_of_entry_id IS NULL OR reversal_of_entry_id <> id);
