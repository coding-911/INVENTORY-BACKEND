package kr.co.unipoint.asset.cost;

import static org.assertj.core.api.Assertions.assertThat;

import java.util.List;
import kr.co.unipoint.asset.support.TestcontainersConfiguration;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.context.annotation.Import;
import org.springframework.jdbc.core.simple.JdbcClient;

/**
 * 금액 컬럼의 자리 수 (COST-05, 2026-11-26 변경). 원래 통화 금액은 소수 3·4자리 통화도 담도록 소수 4자리, 원화 환산은 소수 2자리, 단가는 소수
 * 4자리다. 정수 자리는 모두 16자리 이상이다.
 */
@SpringBootTest
@Import(TestcontainersConfiguration.class)
class AmountColumnScaleTest {

    @Autowired
    JdbcClient jdbc;

    @Test
    void 원래_통화_금액은_소수_4자리_원화_환산은_소수_2자리() {
        List<String> columns = jdbc.sql("""
                        SELECT table_name || '.' || column_name || ' ' || numeric_precision || ',' || numeric_scale
                        FROM information_schema.columns
                        WHERE table_schema = 'cost'
                          AND (table_name, column_name) IN (
                              ('extra_costs', 'amount'), ('extra_costs', 'amount_krw'),
                              ('loan_fees', 'amount'), ('loan_fees', 'amount_krw'),
                              ('line_prices', 'unit_price'), ('line_prices', 'unit_price_krw'),
                              ('opening_costs', 'unit_cost'), ('opening_costs', 'unit_cost_krw'))
                        ORDER BY 1
                        """).query(String.class).list();

        assertThat(columns)
                .containsExactly(
                        "extra_costs.amount 20,4",
                        "extra_costs.amount_krw 18,2",
                        "line_prices.unit_price 19,4",
                        "line_prices.unit_price_krw 19,4",
                        "loan_fees.amount 20,4",
                        "loan_fees.amount_krw 18,2",
                        "opening_costs.unit_cost 19,4",
                        "opening_costs.unit_cost_krw 19,4");
    }
}
