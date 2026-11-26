package kr.co.unipoint.asset.user;

import static org.assertj.core.api.Assertions.assertThat;

import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.SQLException;
import java.util.Map;
import java.util.UUID;
import org.flywaydb.core.Flyway;
import org.junit.jupiter.api.Test;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.jdbc.datasource.SingleConnectionDataSource;
import org.testcontainers.postgresql.PostgreSQLContainer;

/**
 * V5가 예전 역할·금액 권한을 새 기본 역할로 옮기는지 (확정 사항 #106). 이미 계정이 있는 DB(개발 서버의 첫 관리자 등)에 V5를 적용하는 경우다.
 *
 * <p>다른 테스트와 DB를 나누려고 컨테이너를 따로 하나 띄우고 V4까지 적용한 뒤 예전 방식으로 계정을 넣고 V5를 적용한다.
 */
class V5RoleMigrationTest {

    @Test
    void 예전_역할과_금액_권한을_가장_가까운_기본_역할로_옮기고_예전_테이블과_역할을_지운다() throws SQLException {
        try (PostgreSQLContainer postgres = new PostgreSQLContainer("postgres:18")) {
            postgres.start();
            SingleConnectionDataSource dataSource = new SingleConnectionDataSource(
                    postgres.getJdbcUrl(), postgres.getUsername(), postgres.getPassword(), true);
            JdbcClient jdbc = JdbcClient.create(dataSource);
            migrate(dataSource, "4");

            Map<String, UUID> users = Map.of(
                    "admin", oldUser(jdbc, new String[] {"ADMIN", "OPERATOR"}),
                    "operator", oldUser(jdbc, new String[] {"OPERATOR"}),
                    "operatorView", oldUser(jdbc, new String[] {"OPERATOR"}, "COST_VIEW"),
                    "operatorEdit", oldUser(jdbc, new String[] {"OPERATOR"}, "COST_VIEW", "COST_EDIT"),
                    "viewer", oldUser(jdbc, new String[] {"VIEWER"}),
                    "viewerView", oldUser(jdbc, new String[] {"VIEWER"}, "COST_VIEW"),
                    "viewerEdit", oldUser(jdbc, new String[] {"VIEWER"}, "COST_VIEW", "COST_EDIT"),
                    "noRole", oldUser(jdbc, new String[] {}));

            migrate(dataSource, "5");

            assertThat(roleOf(jdbc, users.get("admin"))).isEqualTo("ADMIN");
            assertThat(roleOf(jdbc, users.get("operator"))).isEqualTo("OPERATOR_BASIC");
            assertThat(roleOf(jdbc, users.get("operatorView"))).isEqualTo("OPERATOR_COST_VIEW");
            assertThat(roleOf(jdbc, users.get("operatorEdit"))).isEqualTo("OPERATOR_COST_EDIT");
            assertThat(roleOf(jdbc, users.get("viewer"))).isEqualTo("USER_BASIC");
            assertThat(roleOf(jdbc, users.get("viewerView"))).isEqualTo("USER_COST_VIEW");
            assertThat(roleOf(jdbc, users.get("viewerEdit"))).isEqualTo("USER_COST_VIEW");
            assertThat(roleOf(jdbc, users.get("noRole"))).isEqualTo("USER_BASIC");
            assertThat(jdbc.sql("""
                            SELECT count(*) FROM information_schema.tables
                            WHERE table_schema = 'auth' AND table_name IN ('user_roles', 'user_permissions')
                            """).query(Integer.class).single()).isZero();
            assertThat(jdbc.sql("SELECT count(*) FROM auth.roles WHERE code IN ('OPERATOR', 'VIEWER')")
                            .query(Integer.class)
                            .single())
                    .isZero();
            dataSource.destroy();
        }
    }

    @Test
    void 역할_코드는_대문자_숫자_밑줄만이고_코드_이름은_삭제된_것을_빼고_겹치지_않는다() throws SQLException {
        try (PostgreSQLContainer postgres = new PostgreSQLContainer("postgres:18")) {
            postgres.start();
            SingleConnectionDataSource dataSource = new SingleConnectionDataSource(
                    postgres.getJdbcUrl(), postgres.getUsername(), postgres.getPassword(), true);
            JdbcClient jdbc = JdbcClient.create(dataSource);
            migrate(dataSource, "5");

            assertThat(fails(postgres, "INSERT INTO auth.roles (code, name) VALUES ('bad-code', '잘못된 코드')"))
                    .isTrue();
            assertThat(fails(postgres, "INSERT INTO auth.roles (code, name) VALUES ('ADMIN', '다른 이름')"))
                    .isTrue();
            assertThat(fails(postgres, "INSERT INTO auth.roles (code, name) VALUES ('NEW_ROLE', '관리자')"))
                    .isTrue();
            jdbc.sql("UPDATE auth.roles SET deleted_at = now() WHERE code = 'USER_BASIC'")
                    .update();
            assertThat(fails(postgres, "INSERT INTO auth.roles (code, name) VALUES ('USER_BASIC', '일반 사용자')"))
                    .isFalse();
            dataSource.destroy();
        }
    }

    private static void migrate(SingleConnectionDataSource dataSource, String target) {
        Flyway.configure().dataSource(dataSource).target(target).load().migrate();
    }

    private static UUID oldUser(JdbcClient jdbc, String[] roles, String... permissions) {
        UUID id = jdbc.sql("""
                        INSERT INTO auth.users (login_id, name, password_hash, created_by)
                        VALUES (:loginId, '예전 계정', 'x', uuidv7())
                        RETURNING id
                        """)
                .param("loginId", "old-" + UUID.randomUUID().toString().substring(0, 8))
                .query(UUID.class)
                .single();
        for (String role : roles) {
            jdbc.sql("INSERT INTO auth.user_roles (user_id, role_id) SELECT :id, id FROM auth.roles WHERE code = :role")
                    .param("id", id)
                    .param("role", role)
                    .update();
        }
        for (String permission : permissions) {
            jdbc.sql("INSERT INTO auth.user_permissions (user_id, permission) VALUES (:id, :permission)")
                    .param("id", id)
                    .param("permission", permission)
                    .update();
        }
        return id;
    }

    private static String roleOf(JdbcClient jdbc, UUID userId) {
        return jdbc.sql("SELECT r.code FROM auth.users u JOIN auth.roles r ON r.id = u.role_id WHERE u.id = :id")
                .param("id", userId)
                .query(String.class)
                .single();
    }

    /** 제약 위반을 따로 연결해서 본다(실패한 문장이 공용 연결을 망가뜨리지 않게). */
    private static boolean fails(PostgreSQLContainer postgres, String sql) {
        try (Connection connection = DriverManager.getConnection(
                        postgres.getJdbcUrl(), postgres.getUsername(), postgres.getPassword());
                var statement = connection.createStatement()) {
            statement.execute(sql);
            return false;
        } catch (SQLException e) {
            return true;
        }
    }
}
