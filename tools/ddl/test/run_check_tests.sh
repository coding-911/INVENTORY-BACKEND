#!/bin/bash
# C9–C12 점검 쿼리 시험: 정상 데이터는 0행, 일부러 틀어 놓으면 잡히는지
# 사용: (tools/ddl에서 gen.py로 out/을 만든 뒤) ./test/run_check_tests.sh  — 접속은 PGHOST 등 표준 환경 변수
S="$(cd "$(dirname "$0")" && pwd)"
D="$S/../out"
p(){ psql -q -v ON_ERROR_STOP=1 -d dbt $*; }
psql -q -c 'DROP DATABASE IF EXISTS dbt' -c 'CREATE DATABASE dbt' 2>/dev/null
p < $D/asset_prod_full.sql > /dev/null
p < $S/c9_c15_seed_uuid.sql > /dev/null || { echo SEED FAILED; exit 1; }
echo "[정상] 점검 결과 행 수: $(cat $S/c9_c15.sql | p -At | grep -c .)"
t(){ echo "== $1"; { echo "BEGIN;"; echo "$2"; cat $S/c9_c15.sql; echo "ROLLBACK;"; } | p -At 2>&1 | grep -v '^$'; }
t "X1 발주 처리 수량 7로 틀어짐 → C9" "UPDATE project.trade_lines SET fulfilled_quantity=7 WHERE id=u(1);"
t "X2 전환 문서 처리 수량 1 → C9(전환)" "UPDATE project.trade_lines SET fulfilled_quantity=1 WHERE id=u(4);"
t "X3 배정 소진 3 → C10" "UPDATE allocation.allocations SET consumed_quantity=3 WHERE id=u(1);"
t "X4 반품 수량 0 → C11·C9(매출)" "UPDATE delivery.delivery_lines SET returned_quantity=0 WHERE id=u(1);"
t "X5 장비 상태 불량으로 → C12" "UPDATE equipment.equipment SET status='DEFECTIVE' WHERE id=u(1);"
t "X6 반품 취소했는데 반품 수량 그대로 → C11" "INSERT INTO inventory.stock_transactions(id,transaction_no,transaction_type,business_date,status,request_id,related_transaction_id,created_by)  VALUES (u(8),'T8','REVERSAL','2026-11-04','POSTED','r8',u(6),u(1));"
t "X7 수리 장비 현재 위치 틀어짐 → C12" "UPDATE equipment.equipment SET current_location_id=u(1) WHERE id=u(2);"
t "X8 대차 정산 수량 1로 틀어짐 → C13" "UPDATE loan.loan_lines SET settled_quantity=1 WHERE id=u(1);"
t "X9 정산 기록 반려됨(합계 0) → C9(전환)·C13" "UPDATE loan.loan_settlements SET status='REJECTED' WHERE loan_line_id=u(1);"
t "X10 검수 대기 재고 0(불량 판정)인데 배정 그대로 → C14" "UPDATE inventory.stock_balances SET quantity=0 WHERE stock_condition='INSPECTION' AND product_id=u(1);"
t "X11 받은 수량 1인데 정산 2 → C15" "UPDATE loan.loan_lines SET moved_quantity=1 WHERE id=u(1);"
