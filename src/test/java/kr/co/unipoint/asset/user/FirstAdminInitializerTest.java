package kr.co.unipoint.asset.user;

import static org.assertj.core.api.Assertions.assertThat;

import java.util.List;
import java.util.Map;
import kr.co.unipoint.asset.support.TestcontainersConfiguration;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.ApplicationRunner;
import org.springframework.boot.DefaultApplicationArguments;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.context.annotation.Import;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.security.crypto.password.PasswordEncoder;

/** 사용 중인 관리자가 없으면 앱이 켜질 때 환경 변수의 아이디·비밀번호로 관리자를 만든다. */
@SpringBootTest(properties = {"asset.first-admin.login-id=first-admin", "asset.first-admin.password=first-pw"})
@Import(TestcontainersConfiguration.class)
class FirstAdminInitializerTest {

    @Autowired
    JdbcClient jdbc;

    @Autowired
    PasswordEncoder passwordEncoder;

    @Autowired
    List<ApplicationRunner> runners;

    @Test
    void 사용_중인_관리자가_없으면_비밀번호를_바꿔야_하는_관리자를_만들고_있으면_만들지_않는다() throws Exception {
        // 다른 테스트가 먼저 켠 앱이 만든 관리자까지 모두 지워 "사용 중인 관리자 없음"을 만든다
        jdbc.sql("""
                        UPDATE auth.users SET deleted_at = now(), deleted_by = id
                        WHERE deleted_at IS NULL
                          AND role_id = (SELECT id FROM auth.roles WHERE code = 'ADMIN')
                        """).update();

        runAll();
        runAll(); // 두 번째는 관리자가 있으므로 만들지 않는다

        List<Map<String, Object>> admins = jdbc.sql("""
                        SELECT u.id, u.created_by, u.password_hash, u.must_change_password, u.is_active
                        FROM auth.users u
                        JOIN auth.roles r ON r.id = u.role_id
                        WHERE r.code = 'ADMIN' AND u.login_id = 'first-admin' AND u.deleted_at IS NULL
                        """).query().listOfRows();
        assertThat(admins).hasSize(1);
        Map<String, Object> admin = admins.getFirst();
        assertThat(admin.get("created_by")).isEqualTo(admin.get("id"));
        assertThat(admin).containsEntry("must_change_password", true).containsEntry("is_active", true);
        assertThat(passwordEncoder.matches("first-pw", (String) admin.get("password_hash")))
                .isTrue();
    }

    private void runAll() throws Exception {
        for (ApplicationRunner runner : runners) {
            runner.run(new DefaultApplicationArguments());
        }
    }
}
