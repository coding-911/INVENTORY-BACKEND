# -*- coding: utf-8 -*-
"""PostgreSQL DDL 3종 생성기.

  asset_v1_create.sql       처음 생성용: 테이블·PK·FK·NOT NULL·기본값 + 핵심 제약
  asset_v2_constraints.sql  추후 수정용: 서비스 테스트 후 나머지 제약을 ALTER로 추가
  asset_prod_full.sql       운영 최종본: v1 + v2를 한 파일로 합친 것

세 파일 모두 gen.py의 같은 테이블 정의에서 만든다. 제약 이름은 세 파일에서 동일하다.
"""
import re
import sys

import gen
from gen import TABLES, BY_NAME, q, esc, pg_type, SEED_PG, fk_parts, fk_indexes

DATE = "2026-11-26"

# ---------------------------------------------------------------- 핵심 제약 (v1에 포함)
# 기준: ① 서비스 로직이 이 제약에 기대어 동작하거나(업서트·중복 요청 방지·로그인 조회)
#       ② 재고·수량이 틀어지는 것을 막는 마지막 안전망인 것.
CORE = {
    # 서비스 로직이 기대는 키
    "ux_users_login_id": "로그인 ID로 사용자 1명을 찾는다(삭제된 계정 제외)",
    "uq_stock_transactions_request_id": "중복 요청 방지(INV-08)",
    "ux_stock_balances_key": "현재 재고 업서트(ON CONFLICT) 대상 키(INV-05)",
    "uq_period_closings_period": "월별 마감 행 1개, 마감 잠금 대상(INV-45)",
    "ux_monthly_stock_snapshots_key": "스냅샷 버전별 재고 키 1행",
    # 원장 보호
    "fn_ledger_entries_append_only": "원장 수정·삭제 차단 함수(INV-01)",
    "trg_ledger_entries_append_only": "원장 수정·삭제 차단 트리거(INV-01)",
    "uq_ledger_entries_reversal_of_entry_id": "원장 행 1회만 취소(INV-10)",
    "ck_ledger_entries_4": "원장 수량 0 금지(INV-02)",
    "ck_ledger_entries_3": "원장 소유 구분 일관성(INV-06), 재고 키가 섞이지 않게",
    # 현재 재고
    "ck_stock_balances_4": "음수 재고 금지(INV-03)",
    "ck_stock_balances_3": "현재 재고 소유 구분 일관성(INV-06)",
    # 수량 안전망
    "ck_bundle_components_1": "구성 수량 > 0",
    "ck_trade_lines_1": "문서 수량 > 0",
    "ck_trade_lines_2": "처리 수량 >= 0",
    "ck_trade_lines_3": "마감 수량 >= 0",
    "ck_trade_lines_4": "기준일 이전 처리 + 처리 + 마감 <= 문서 수량(INV-26)",
    "ck_trade_lines_6": "기준일 이전 처리 수량 >= 0(INV-55)",
    "ck_allocations_1": "배정 수량 > 0",
    "ck_allocations_2": "소진 수량 <= 배정 수량(INV-37)",
    "ck_delivery_lines_1": "납품 수량 > 0",
    "ck_delivery_lines_2": "반품 수량 <= 납품 수량(INV-32)",
    "ck_delivery_returns_1": "반품 수량 > 0",
    "ck_loan_lines_1": "대차 수량 > 0",
    "ck_loan_lines_2": "정산 수량 <= 대차 수량(INV-39)",
    "ck_loan_settlements_1": "정산 기록 수량 > 0",
}

# ---------------------------------------------------------------- 나중 Flyway 마이그레이션이 처음부터 건 제약 (v1에 포함)
# 개발을 시작한 뒤 DB 구조의 원본은 Flyway다. 아래는 V3·V5가 이미 걸었으므로 v2로 미루지 않는다.
# 그래서 v1 파일 = Flyway V1~V5를 적용한 DB와 같은 구조다 (verify.sh가 비교).
APPLIED = {
    "ux_spring_session_session_id": "세션 ID로 세션 1개를 찾는다(V3, Spring Session JDBC)",
    "ck_roles_code": "역할 코드는 대문자·숫자·밑줄(V5, #106)",
    "ux_roles_code": "역할 코드는 삭제된 것을 빼고 하나(V5, #106)",
    "ux_roles_name": "역할 이름은 삭제된 것을 빼고 하나(V5, #106)",
}

# ---------------------------------------------------------------- 보강 제안 P1~P5 (v2·운영본에만)
PROPOSALS = [
    ("P1", "ux_allocations_active_equipment", "장비 1대에 활성 배정 1건(INV-24)",
     """CREATE UNIQUE INDEX ux_allocations_active_equipment
    ON allocation.allocations (equipment_id)
    WHERE status = 'ACTIVE' AND equipment_id IS NOT NULL;"""),
    ("P2", "ck_ledger_entries_equipment_unit", "시리얼 장비 원장 줄은 수량 ±1(INV-19)",
     "ALTER TABLE inventory.ledger_entries ADD CONSTRAINT ck_ledger_entries_equipment_unit "
     "CHECK (equipment_id IS NULL OR quantity_delta IN (1, -1));"),
    ("P2", "ck_delivery_lines_equipment_unit", "시리얼 장비 납품 줄은 수량 1(INV-19)",
     "ALTER TABLE delivery.delivery_lines ADD CONSTRAINT ck_delivery_lines_equipment_unit "
     "CHECK (equipment_id IS NULL OR quantity = 1);"),
    ("P2", "ck_allocations_equipment_unit", "시리얼 장비 배정은 수량 1(INV-19)",
     "ALTER TABLE allocation.allocations ADD CONSTRAINT ck_allocations_equipment_unit "
     "CHECK (equipment_id IS NULL OR quantity = 1);"),
    ("P3", "ck_line_prices_krw_rate", "원화 단가는 환율 1(INV-52)",
     "ALTER TABLE cost.line_prices ADD CONSTRAINT ck_line_prices_krw_rate "
     "CHECK (currency <> 'KRW' OR exchange_rate = 1);"),
    ("P3", "ck_extra_costs_krw_rate", "원화 부대비용은 환율 1(INV-52)",
     "ALTER TABLE cost.extra_costs ADD CONSTRAINT ck_extra_costs_krw_rate "
     "CHECK (currency <> 'KRW' OR exchange_rate = 1);"),
    ("P3", "ck_loan_fees_krw_rate", "원화 대여료는 환율 1(INV-52)",
     "ALTER TABLE cost.loan_fees ADD CONSTRAINT ck_loan_fees_krw_rate "
     "CHECK (currency <> 'KRW' OR exchange_rate = 1);"),
    ("P3", "ck_opening_costs_krw_rate", "원화 초기 재고 단가는 환율 1(INV-52)",
     "ALTER TABLE cost.opening_costs ADD CONSTRAINT ck_opening_costs_krw_rate "
     "CHECK (currency <> 'KRW' OR exchange_rate = 1);"),
    ("P4", "fn_ledger_entries_closed_period", "마감된 달 원장 추가 차단 함수(INV-15, INV-46)",
     """CREATE OR REPLACE FUNCTION inventory.fn_ledger_entries_closed_period()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    IF EXISTS (SELECT 1 FROM inventory.period_closings
               WHERE period = to_char(NEW.business_date, 'YYYY-MM') AND status = 'CLOSED') THEN
        RAISE EXCEPTION 'period % is closed', to_char(NEW.business_date, 'YYYY-MM');
    END IF;
    RETURN NEW;
END;
$$;"""),
    ("P4", "trg_ledger_entries_closed_period", "마감된 달 원장 추가 차단 트리거(INV-15, INV-46)",
     """CREATE TRIGGER trg_ledger_entries_closed_period
    BEFORE INSERT ON inventory.ledger_entries
    FOR EACH ROW EXECUTE FUNCTION inventory.fn_ledger_entries_closed_period();"""),
    ("P5", "ck_ledger_entries_reversal_self", "자기 자신 취소 금지(INV-11)",
     "ALTER TABLE inventory.ledger_entries ADD CONSTRAINT ck_ledger_entries_reversal_self "
     "CHECK (reversal_of_entry_id IS NULL OR reversal_of_entry_id <> id);"),
]

EXTRA_NAME = re.compile(r"\b((?:ux|trg|fn|ck)_\w+)")


def extra_name(stmt):
    return EXTRA_NAME.search(stmt).group(1)


def constraints(t):
    """테이블의 UNIQUE·CHECK·추가 구문을 (이름, 종류, 내용) 목록으로. 이름은 gen.py와 동일."""
    items = []
    for u in t["uniques"]:
        items.append((f'uq_{t["name"]}_{"_".join(u)}', "unique", u))
    for i, ck in enumerate(t["checks"], 1):
        items.append((f'ck_{t["name"]}_{i}', "check", ck))
    for stmt in t["pg_extra"]:
        items.append((extra_name(stmt), "extra", stmt))
    return items


ALL_NAMES = {n for t in TABLES for n, _, _ in constraints(t)}
missing = (set(CORE) | set(APPLIED)) - ALL_NAMES
assert not missing, f"CORE/APPLIED names not found: {missing}"


def is_core(name):
    return name in CORE or name in APPLIED


# ---------------------------------------------------------------- 공통 조각
def header(title, lines):
    out = ["-- ============================================================",
           f"-- 자산관리 시스템 PostgreSQL DDL — {title}",
           f"-- 생성: {DATE} / 기준: 노션 '테이블 정의서', '불변 조건 목록'",
           "-- 대상: PostgreSQL 18 이상 (uuidv7(), UNIQUE NULLS NOT DISTINCT 사용)"]
    out += [f"-- {l}" for l in lines]
    out += ["-- ============================================================", ""]
    return out


def create_tables(include):
    out = []
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
        for name, kind, body in constraints(t):
            if not include(name):
                continue
            if kind == "unique":
                lines.append(f'    CONSTRAINT {name} UNIQUE ({", ".join(body)})')
            elif kind == "check":
                lines.append(f'    CONSTRAINT {name} CHECK ({body})')
        out.append(f"CREATE TABLE {q(t)} (\n" + ",\n".join(lines) + "\n);\n")
    return out


def foreign_keys_and_indexes():
    out = ["-- ---------------------------------------------------------------- 외래 키"]
    for t in TABLES:
        for fk in t["fks"]:
            col, ref, refcol, on_delete = fk_parts(fk)
            out.append(f'ALTER TABLE {q(t)} ADD CONSTRAINT fk_{t["name"]}_{col} '
                       f'FOREIGN KEY ({col}) REFERENCES {q(ref)} ({refcol}){on_delete};')
    out.append("")
    out.append("-- ---------------------------------------------------------------- 조회 인덱스")
    for t in TABLES:
        for idx in t["indexes"]:
            out.append(f'CREATE INDEX ix_{t["name"]}_{"_".join(idx)[:40]} ON {q(t)} ({", ".join(idx)});')
        for col in fk_indexes(t):
            out.append(f'CREATE INDEX ix_{t["name"]}_{col} ON {q(t)} ({col});')
    out.append("")
    return out


def extras(include, title):
    out = [f"-- ---------------------------------------------------------------- {title}"]
    for t in TABLES:
        for name, kind, body in constraints(t):
            if kind == "extra" and include(name):
                why = CORE.get(name) or APPLIED.get(name)
                out.append(f"-- {why}" if why else f"-- {name}")
                out.append(body)
    out.append("")
    return out


def comments():
    out = ["-- ---------------------------------------------------------------- 주석"]
    for t in TABLES:
        out.append(f"COMMENT ON TABLE {q(t)} IS '{esc(t['comment'])}';")
        for c in t["cols"]:
            if c["comment"]:
                out.append(f"COMMENT ON COLUMN {q(t)}.{c['name']} IS '{esc(c['comment'])}';")
    out.append("")
    return out


def deferred_alters():
    """v1에서 뺀 UNIQUE·CHECK·추가 구문을 ALTER로."""
    out = []
    for t in TABLES:
        block = []
        for name, kind, body in constraints(t):
            if is_core(name):
                continue
            if kind == "unique":
                block.append(f'ALTER TABLE {q(t)} ADD CONSTRAINT {name} UNIQUE ({", ".join(body)});')
            elif kind == "check":
                block.append(f'ALTER TABLE {q(t)} ADD CONSTRAINT {name} CHECK ({body});')
            else:
                block.append(body)
        if block:
            out.append(f"-- {q(t)} — {t['comment']}")
            out += block
            out.append("")
    return out


def proposals():
    out = ["-- ---------------------------------------------------------------- 보강 제안 P1~P5 (불변 조건 목록 9절)"]
    for pid, name, desc, stmt in PROPOSALS:
        out.append(f"-- {pid} {desc}")
        out.append(stmt)
    out.append("")
    out.append("-- P4 주의: 마감 작업은 해당 월 period_closings 행을 FOR UPDATE로 잠그고,")
    out.append("--          원장 입력 트랜잭션은 같은 행을 FOR SHARE로 읽어 순서를 보장한다.")
    out.append("")
    return out


GRANT_NOTE = ["-- 운영 계정 권한 (원장 보호, INV-01):",
              "-- REVOKE UPDATE, DELETE ON inventory.ledger_entries FROM app_user;"]


# ---------------------------------------------------------------- 파일 3종
def gen_v1():
    out = header("① 처음 생성용 (v1)", [
        "포함: 스키마, 테이블, PK, FK, NOT NULL, 기본값, 조회 인덱스, 주석, 초기 데이터",
        "      + 핵심 제약(서비스 로직이 기대는 키, 원장 보호, 수량 안전망) — 파일 끝 목록 참고",
        "구조: Flyway V1~V5를 적용한 DB와 같다(verify.sh로 비교). 이후 DB 변경은 새 Flyway 마이그레이션으로 한다",
        "제외: 코드 목록 CHECK, 조건부 CHECK, 업무 키 UNIQUE, 보강 제안 P1~P5",
        "      → 서비스 테스트를 마친 뒤 asset_v2_constraints.sql로 추가한다"])
    out += ["BEGIN;", ""]
    out += create_tables(is_core)
    out += foreign_keys_and_indexes()
    out += extras(is_core, "핵심 제약 (트리거·부분 유니크)")
    out += comments()
    out.append(SEED_PG)
    out.append("COMMIT;")
    out.append("")
    out.append("-- 이 파일에 포함된 핵심 제약 목록")
    for name, why in CORE.items():
        out.append(f"--   {name:<42} {why}")
    out.append("-- 나중 Flyway 마이그레이션이 처음부터 건 제약 (v2로 미루지 않음)")
    for name, why in APPLIED.items():
        out.append(f"--   {name:<42} {why}")
    out.append("")
    out += GRANT_NOTE
    return "\n".join(out) + "\n"


def gen_v2():
    out = header("② 추후 수정용 (v2, 제약 추가)", [
        "전제: asset_v1_create.sql이 적용된 DB (= Flyway V1~V5가 적용된 DB)",
        "내용: v1에서 뺀 CHECK·UNIQUE·부분 유니크 + 보강 제안 P1~P5",
        "주의: ADD CONSTRAINT는 기존 데이터를 검사한다. 위반 데이터가 있으면 실패하고",
        "      전체가 롤백되므로, 실패 메시지의 제약 이름으로 데이터를 정리한 뒤 다시 실행한다.",
        "      협의 결과로 코드 목록이 바뀌었으면 gen.py를 고쳐 다시 생성한 뒤 적용한다."])
    out += ["BEGIN;", ""]
    out.append("-- ---------------------------------------------------------------- v1에서 미룬 제약")
    out += deferred_alters()
    out += proposals()
    out.append("COMMIT;")
    return "\n".join(out) + "\n"


def gen_prod():
    everything = lambda name: True
    out = header("③ 운영 최종본 (v1 + v2)", [
        "운영 DB를 처음 만들 때 이 파일 하나만 실행한다.",
        "v1 → v2를 순서대로 적용한 DB와 스키마가 같다 (생성 시 자동 비교).",
        "참고용: 운영 DB도 Flyway 마이그레이션으로 만든다. 이 파일은 v2까지 다 적용한 최종 구조를 한 파일로 본다."])
    out += ["BEGIN;", ""]
    out += create_tables(everything)
    out += foreign_keys_and_indexes()
    out += extras(everything, "트리거·부분 유니크")
    out += proposals()
    out += comments()
    out.append(SEED_PG)
    out.append("COMMIT;")
    out.append("")
    out += GRANT_NOTE
    return "\n".join(out) + "\n"


if __name__ == "__main__":
    outdir = sys.argv[1] if len(sys.argv) > 1 else "out"
    files = {"asset_v1_create.sql": gen_v1(),
             "asset_v2_constraints.sql": gen_v2(),
             "asset_prod_full.sql": gen_prod()}
    for fn, body in files.items():
        with open(f"{outdir}/{fn}", "w", encoding="utf-8") as f:
            f.write(body)
    total = len(ALL_NAMES)
    print(f"constraints(UNIQUE/CHECK/extra): {total} | core(v1): {len(CORE)} | applied(v1): {len(APPLIED)} | "
          f"deferred(v2): {total - len(CORE) - len(APPLIED)} | proposals(v2): {len(PROPOSALS)}")
