CREATE OR REPLACE FUNCTION u(int) RETURNS uuid LANGUAGE sql IMMUTABLE AS $$ SELECT lpad(to_hex($1),32,'0')::uuid $$;
\set ON_ERROR_STOP 1
INSERT INTO auth.users(id,login_id,name,password_hash,created_by)  VALUES (u(1),'a','a','x',u(1));
INSERT INTO product.products(id,category_id,created_by,item_code,product_name,serial_managed) 
  SELECT u(1),(SELECT id FROM product.product_categories ORDER BY sort_order LIMIT 1),u(1),'IC-Q','PDU',false UNION ALL
  SELECT u(2),(SELECT id FROM product.product_categories ORDER BY sort_order LIMIT 1),u(1),'IC-S','UPS',true;
INSERT INTO partner.partners(id,partner_name,created_by)  VALUES
  (u(1),'공급사',u(1)),(u(2),'고객사',u(1)),(u(3),'수리처',u(1)),(u(4),'차입처',u(1));
INSERT INTO warehouse.warehouses(id,warehouse_code,warehouse_name,created_by)  VALUES (u(1),'W1','본사',u(1));
INSERT INTO warehouse.locations(id,location_code,location_name,location_type,warehouse_id,partner_id,created_by)  VALUES
  (u(1),'L1','B4','INTERNAL',u(1),NULL,u(1)),(u(2),'LR','수리처','REPAIR',NULL,u(3),u(1));
INSERT INTO project.projects(id,project_code,project_name,created_by)  VALUES (u(1),'P1','A',u(1));
INSERT INTO project.trade_documents(id,project_id,trade_type,partner_id,document_date,status,created_by)  VALUES
  (u(1),u(1),'PURCHASE',u(1),'2026-11-01','CONFIRMED',u(1)),(u(2),u(1),'SALES',u(2),'2026-11-01','CONFIRMED',u(1)),(u(3),u(1),'PURCHASE',u(4),'2026-11-05','CONFIRMED',u(1));
-- 처리 수량: 발주1 = 입고 8 − 공급사 반품 1 + (입고 2 − 취소 2) + 직납 1 = 8 / 발주2 = 2 / 매출1 = (4 − 반품 1) + 직납 1 = 4 / 전환 문서 = 2
INSERT INTO project.trade_lines(id,document_id,line_no,product_id,quantity,fulfilled_quantity,created_by)  VALUES
  (u(1),u(1),1,u(1),10,8,u(1)),(u(2),u(1),2,u(2),2,2,u(1)),(u(3),u(2),1,u(1),5,4,u(1)),(u(4),u(3),1,u(1),2,2,u(1));
INSERT INTO inventory.stock_transactions(id,transaction_no,transaction_type,business_date,status,request_id,related_transaction_id,created_by)  VALUES
  (u(1),'T1','RECEIPT','2026-11-01','POSTED','r1',NULL,u(1)),
  (u(2),'T2','SUPPLIER_RETURN','2026-11-02','POSTED','r2',NULL,u(1)),
  (u(3),'T3','RECEIPT','2026-11-02','POSTED','r3',NULL,u(1)),
  (u(4),'T4','REVERSAL','2026-11-02','POSTED','r4',u(3),u(1)),
  (u(5),'T5','ISSUE','2026-11-03','POSTED','r5',NULL,u(1)),
  (u(6),'T6','CUSTOMER_RETURN','2026-11-04','POSTED','r6',NULL,u(1)),
  (u(7),'T7','REPAIR_OUT','2026-11-04','POSTED','r7',NULL,u(1));
INSERT INTO equipment.equipment(id,product_id,serial_no,status,current_location_id,last_event_date,created_by)  VALUES
  (u(1),u(2),'SN-1','IN_STOCK',u(1),'2026-11-01',u(1)),(u(2),u(2),'SN-2','IN_REPAIR',u(2),'2026-11-04',u(1));
INSERT INTO inventory.ledger_entries(transaction_id,line_no,product_id,location_id,stock_condition,quantity_delta,business_date,equipment_id,trade_line_id,reversal_of_entry_id,item_code_snapshot,product_name_snapshot,created_by) VALUES
  (u(1),1,u(1),u(1),'AVAILABLE',8,'2026-11-01',NULL,u(1),NULL,'IC-Q','PDU',u(1)),
  (u(1),2,u(2),u(1),'AVAILABLE',1,'2026-11-01',u(1),u(2),NULL,'IC-S','UPS',u(1)),
  (u(1),3,u(2),u(1),'AVAILABLE',1,'2026-11-01',u(2),u(2),NULL,'IC-S','UPS',u(1)),
  (u(2),1,u(1),u(1),'AVAILABLE',-1,'2026-11-02',NULL,u(1),NULL,'IC-Q','PDU',u(1)),
  (u(3),1,u(1),u(1),'AVAILABLE',2,'2026-11-02',NULL,u(1),NULL,'IC-Q','PDU',u(1));
INSERT INTO inventory.ledger_entries(transaction_id,line_no,product_id,location_id,stock_condition,quantity_delta,business_date,trade_line_id,reversal_of_entry_id,item_code_snapshot,product_name_snapshot,created_by)
  SELECT u(4),1,u(1),u(1),'AVAILABLE',-2,'2026-11-02',u(1),id,'IC-Q','PDU',u(1) FROM inventory.ledger_entries WHERE transaction_id=u(3);
INSERT INTO inventory.ledger_entries(transaction_id,line_no,product_id,location_id,stock_condition,quantity_delta,business_date,equipment_id,trade_line_id,item_code_snapshot,product_name_snapshot,created_by) VALUES
  (u(5),1,u(1),u(1),'AVAILABLE',-4,'2026-11-03',NULL,u(3),'IC-Q','PDU',u(1)),
  (u(6),1,u(1),u(1),'INSPECTION',1,'2026-11-04',NULL,NULL,'IC-Q','PDU',u(1)),
  (u(7),1,u(2),u(1),'AVAILABLE',-1,'2026-11-04',u(2),NULL,'IC-S','UPS',u(1)),
  (u(7),2,u(2),u(2),'IN_REPAIR',1,'2026-11-04',u(2),NULL,'IC-S','UPS',u(1));
INSERT INTO delivery.deliveries(id,delivery_no,project_id,customer_partner_id,delivery_date,route,status,transaction_id,created_by)  VALUES
  (u(1),'D1',u(1),u(2),'2026-11-03','WAREHOUSE','POSTED',u(5),u(1)),(u(2),'D2',u(1),u(2),'2026-11-03','DIRECT','POSTED',NULL,u(1));
INSERT INTO delivery.delivery_lines(id,delivery_id,line_no,product_id,quantity,sales_line_id,purchase_line_id,returned_quantity)  VALUES
  (u(1),u(1),1,u(1),4,u(3),NULL,1),(u(2),u(2),1,u(1),1,u(3),u(1),0);
INSERT INTO delivery.delivery_returns(delivery_line_id,quantity,return_date,transaction_id,created_by) VALUES (u(1),1,'2026-11-04',u(6),u(1));
INSERT INTO allocation.allocations(id,product_id,quantity,consumed_quantity,target_type,project_id,source_type,status,created_by)  VALUES
  (u(1),u(1),3,2,'PROJECT',u(1),'STOCK','ACTIVE',u(1));
INSERT INTO allocation.allocation_events(allocation_id,action,quantity,acted_by) VALUES (u(1),'ALLOCATE',3,u(1)),(u(1),'CONSUME',3,u(1)),(u(1),'CONSUME',-1,u(1));
INSERT INTO loan.loan_documents(id,loan_no,direction,partner_id,settlement_method,status,converted_trade_document_id,created_by)  VALUES
  (u(1),'LN1','IN',u(4),'CONVERT','SETTLED',u(3),u(1));
INSERT INTO loan.loan_lines(id,loan_id,line_no,product_id,quantity,moved_quantity,settled_quantity)  VALUES (u(1),u(1),1,u(1),2,2,2);
INSERT INTO loan.loan_settlements(loan_line_id,settled_date,method,quantity,settled_product_id,status,trade_document_id,created_by) VALUES (u(1),'2026-11-05','CONVERT',2,u(1),'POSTED',u(3),u(1));
-- C14용: 고객 반품 검수 대기 1 (자사 창고), 검수 대기 배정 1
INSERT INTO inventory.stock_balances(product_id,location_id,stock_condition,quantity) VALUES (u(1),u(1),'INSPECTION',1);
INSERT INTO allocation.allocations(id,product_id,quantity,consumed_quantity,target_type,project_id,source_type,source_trade_line_id,status,created_by)  VALUES
  (u(2),u(1),1,0,'PROJECT',u(1),'RECEIVED',u(1),'ACTIVE',u(1));
INSERT INTO allocation.allocation_events(allocation_id,action,quantity,acted_by) VALUES (u(2),'CONVERT',1,u(1));
