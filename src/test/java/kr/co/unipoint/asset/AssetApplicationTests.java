package kr.co.unipoint.asset;

import static org.assertj.core.api.Assertions.assertThat;

import java.util.List;
import kr.co.unipoint.asset.support.TestcontainersConfiguration;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.context.annotation.Import;
import org.springframework.jdbc.core.simple.JdbcClient;

@SpringBootTest
@Import(TestcontainersConfiguration.class)
class AssetApplicationTests {

    @Autowired
    JdbcClient jdbc;

    @Test
    void contextLoads() {}

    @Test
    void connectsToPostgres18() {
        String version = jdbc.sql("SHOW server_version").query(String.class).single();

        assertThat(version).startsWith("18.");
    }

    @Test
    void appliesBaselineMigration() {
        List<String> versions = jdbc.sql(
                        "SELECT version FROM flyway_schema_history WHERE success ORDER BY installed_rank")
                .query(String.class)
                .list();
        // T_로 시작하는 것은 다른 테스트가 만든 역할이다
        List<String> roles = jdbc.sql("SELECT code FROM auth.roles WHERE code NOT LIKE 'T\\_%' ORDER BY code")
                .query(String.class)
                .list();

        assertThat(versions).startsWith("1");
        assertThat(roles)
                .containsExactly(
                        "ADMIN",
                        "OPERATOR_BASIC",
                        "OPERATOR_COST_EDIT",
                        "OPERATOR_COST_VIEW",
                        "USER_BASIC",
                        "USER_COST_VIEW"); // V5 기본 역할 (권한 매트릭스 1.5)
    }
}
