package kr.co.unipoint.asset;

import static org.assertj.core.api.Assertions.assertThat;

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
}
