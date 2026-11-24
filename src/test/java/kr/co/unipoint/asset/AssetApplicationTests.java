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
        List<String> roles = jdbc.sql("SELECT code FROM auth.roles ORDER BY code")
                .query(String.class)
                .list();

        assertThat(versions).startsWith("1");
        assertThat(roles).containsExactly("ADMIN", "OPERATOR", "VIEWER"); // V1 초기 데이터
    }
}
