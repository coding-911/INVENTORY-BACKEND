package kr.co.unipoint.asset.support;

import org.springframework.boot.test.context.TestConfiguration;
import org.springframework.boot.testcontainers.service.connection.ServiceConnection;
import org.springframework.context.annotation.Bean;
import org.testcontainers.postgresql.PostgreSQLContainer;

/**
 * DB가 필요한 테스트의 PostgreSQL 18 (docs/dev/conventions.md 9절).
 *
 * <p>컨테이너는 테스트 실행 전체에서 하나를 같이 쓴다. 테스트마다 스프링 설정이 달라 컨텍스트가 여러 개 생겨도 같은
 * 컨테이너를 돌려준다. 접속 정보는 {@link ServiceConnection}이 DataSource에 넣는다.
 */
@TestConfiguration(proxyBeanMethods = false)
public class TestcontainersConfiguration {

    private static final PostgreSQLContainer POSTGRES = new PostgreSQLContainer("postgres:18");

    @Bean
    @ServiceConnection
    PostgreSQLContainer postgres() {
        return POSTGRES;
    }
}
