-- 원래 통화로 넣는 금액은 소수 4자리까지 저장한다 (2026-11-26, COST-05 변경).
-- 소수 3자리 통화(KWD·BHD·OMR·JOD 등)도 다룰 수 있어야 한다. ISO 4217 통화의 소수 자리는 최대 4다.
-- 통화마다 몇 자리까지 받을지는 currencies.minor_unit으로 서버가 검사한다. 정수 자리는 16자리 그대로 둔다.
-- 원화 환산(amount_krw)은 원화라 numeric(18,2) 그대로다. 단가는 이미 numeric(19,4)다.
ALTER TABLE cost.extra_costs
    ALTER COLUMN amount TYPE numeric(20,4);

ALTER TABLE cost.loan_fees
    ALTER COLUMN amount TYPE numeric(20,4);
