#!/bin/bash
# PostgreSQL 18에서 세 DDL 파일의 스키마가 같은지 검증한다: (v1 + v2) == 운영 최종본 == (전체 DDL + 보강 제안)
# 접속은 표준 환경 변수(PGHOST, PGPORT, PGUSER, PGPASSWORD)를 쓴다. 검증용 DB(dba·dbb·dbc·dbv1)를 지웠다 다시 만든다.
# 사용: python3 gen.py out && python3 gen3.py out && ./verify.sh
set -e
cd "$(dirname "$0")"
PSQL="psql"
TMP=$(mktemp -d)
for d in dba dbb dbc dbv1; do $PSQL -q -c "DROP DATABASE IF EXISTS $d" -c "CREATE DATABASE $d" 2>/dev/null; done
run(){ $PSQL -q -v ON_ERROR_STOP=1 -d $1 < $2 > /dev/null; }
run dba out/asset_v1_create.sql; run dba out/asset_v2_constraints.sql
run dbb out/asset_prod_full.sql
run dbc out/asset_schema_postgresql.sql; run dbc proposals.sql
run dbv1 out/asset_v1_create.sql
FP="
select 'col '||table_schema||'.'||table_name||'.'||column_name||' '||data_type||' '||is_nullable||' '||coalesce(column_default,'') from information_schema.columns where table_schema not in ('pg_catalog','information_schema')
union all select 'con '||n.nspname||'.'||t.relname||'.'||c.conname||' '||pg_get_constraintdef(c.oid) from pg_constraint c join pg_class t on t.oid=c.conrelid join pg_namespace n on n.oid=t.relnamespace where n.nspname not in ('pg_catalog','information_schema')
union all select 'idx '||schemaname||'.'||indexname||' '||indexdef from pg_indexes where schemaname not in ('pg_catalog','information_schema')
union all select 'trg '||tgrelid::regclass||'.'||tgname||' '||pg_get_triggerdef(oid) from pg_trigger where not tgisinternal
union all select 'fn '||p.oid::regprocedure::text||' '||md5(prosrc) from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname not in ('pg_catalog','information_schema')
union all select 'cmt '||c.oid::regclass||'.'||coalesce(a.attname,'')||' '||d.description from pg_description d join pg_class c on c.oid=d.objoid left join pg_attribute a on a.attrelid=c.oid and a.attnum=d.objsubid and d.objsubid>0 join pg_namespace n on n.oid=c.relnamespace where n.nspname not in ('pg_catalog','information_schema')
order by 1"
for d in dba dbb dbc dbv1; do $PSQL -At -d $d -c "$FP" > $TMP/fp_$d.txt; test -s $TMP/fp_$d.txt; done
echo "server: $($PSQL -At -c 'show server_version')"
echo "fingerprint lines: $(wc -l < $TMP/fp_dbb.txt)"
echo "== v1+v2 vs prod"; diff $TMP/fp_dba.txt $TMP/fp_dbb.txt && echo IDENTICAL
echo "== prod vs 기존DDL+제안"; diff $TMP/fp_dbb.txt $TMP/fp_dbc.txt && echo IDENTICAL
cnt(){ $PSQL -At -d $1 -c "select string_agg(contype::text||'='||n, ' ' order by contype) from (select contype, count(*) n from pg_constraint c join pg_namespace s on s.oid=c.connamespace where nspname not in ('pg_catalog','information_schema') group by 1) t"; }
echo "v1 only : $(cnt dbv1)"
echo "prod    : $(cnt dbb)"
echo "tables  : $($PSQL -At -d dbb -c "select count(*) from information_schema.tables where table_schema not in ('pg_catalog','information_schema') and table_type='BASE TABLE'") / columns: $($PSQL -At -d dbb -c "select count(*) from information_schema.columns where table_schema not in ('pg_catalog','information_schema')")"
echo "uuidv7 default works: $($PSQL -At -d dbb -c "select 'version='||substr(uuidv7()::text,15,1)")"
