package kr.co.unipoint.asset.user;

import static org.assertj.core.api.Assertions.assertThat;

import jakarta.servlet.http.Cookie;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;
import kr.co.unipoint.asset.support.TestcontainersConfiguration;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.context.annotation.Import;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.test.web.servlet.assertj.MockMvcTester;
import org.springframework.test.web.servlet.assertj.MvcTestResult;
import org.springframework.test.web.servlet.request.RequestPostProcessor;

/** 로그인·로그아웃·내 정보 API와 세션 확인 (API 명세서 1.3·1.14, INV-80). 실제 보안 필터와 DB 세션으로 검사한다. */
@SpringBootTest
@AutoConfigureMockMvc
@Import(TestcontainersConfiguration.class)
class AuthApiTest {

    static final String PASSWORD = "pw-1234";

    @Autowired
    MockMvcTester mvc;

    @Autowired
    JdbcClient jdbc;

    @Autowired
    PasswordEncoder passwordEncoder;

    @Test
    void 로그인하면_내_정보와_HttpOnly_세션_쿠키를_주고_그_쿠키로_내_정보를_본다() {
        String loginId = newLoginId();
        UUID id = createUser(loginId, "OPERATOR", true, false, "COST_VIEW");

        MvcTestResult login = login(loginId, PASSWORD);

        assertThat(login).hasStatus(HttpStatus.OK);
        assertThat(login).bodyJson().extractingPath("$.code").isEqualTo("OK");
        assertThat(login).bodyJson().extractingPath("$.data.id").isEqualTo(id.toString());
        assertThat(login).bodyJson().extractingPath("$.data.loginId").isEqualTo(loginId);
        assertThat(login).bodyJson().extractingPath("$.data.roles").asArray().containsExactly("OPERATOR");
        assertThat(login)
                .bodyJson()
                .extractingPath("$.data.permissions")
                .asArray()
                .containsExactly("COST_VIEW");
        assertThat(login).bodyJson().extractingPath("$.data.mustChangePassword").isEqualTo(false);
        Cookie session = login.getResponse().getCookie("SESSION");
        assertThat(session).isNotNull();
        assertThat(session.isHttpOnly()).isTrue();

        MvcTestResult me = mvc.get().uri("/api/v1/user/me").cookie(session).exchange();

        assertThat(me).hasStatus(HttpStatus.OK);
        assertThat(me).bodyJson().extractingPath("$.data.name").isEqualTo("테스트");
        assertThat(lastLoginAtIsSet(id)).isTrue();
    }

    @Test
    void 세션은_DB에_사용자_ID로_저장되고_마지막_요청_뒤_8시간이면_끝난다() {
        String loginId = newLoginId();
        UUID id = createUser(loginId, "VIEWER", true, false);

        login(loginId, PASSWORD);

        Integer maxInactive = jdbc.sql(
                        "SELECT max_inactive_interval FROM auth.spring_session WHERE principal_name = :id")
                .param("id", id.toString())
                .query(Integer.class)
                .single();
        assertThat(maxInactive).isEqualTo(8 * 60 * 60);
    }

    @Test
    void 비밀번호가_틀리거나_없는_아이디거나_사용_중지면_모두_같은_401_LOGIN_FAILED() {
        String loginId = newLoginId();
        createUser(loginId, "OPERATOR", true, false);
        String inactiveId = newLoginId();
        createUser(inactiveId, "OPERATOR", false, false);

        for (MvcTestResult result : new MvcTestResult[] {
            login(loginId, "wrong"), login("nobody-" + loginId, PASSWORD), login(inactiveId, PASSWORD)
        }) {
            assertThat(result).hasStatus(HttpStatus.UNAUTHORIZED);
            assertThat(result).bodyJson().extractingPath("$.code").isEqualTo("LOGIN_FAILED");
            assertThat(result).bodyJson().extractingPath("$.message").isEqualTo("아이디 또는 비밀번호가 맞지 않습니다");
            assertThat(result.getResponse().getCookie("SESSION")).isNull();
        }
    }

    @Test
    void 아이디_비밀번호가_비면_400_VALIDATION_FAILED() {
        MvcTestResult result = mvc.post()
                .uri("/api/v1/user/login")
                .with(xsrf())
                .contentType(MediaType.APPLICATION_JSON)
                .content("{\"loginId\":\"\"}")
                .exchange();

        assertThat(result).hasStatus(HttpStatus.BAD_REQUEST);
        assertThat(result).bodyJson().extractingPath("$.data.errors.length()").isEqualTo(2);
    }

    @Test
    void 로그인하지_않으면_401_UNAUTHENTICATED를_공통_형식으로() {
        MvcTestResult result = mvc.get().uri("/api/v1/user/me").exchange();

        assertThat(result).hasStatus(HttpStatus.UNAUTHORIZED);
        assertThat(result).bodyJson().extractingPath("$.code").isEqualTo("UNAUTHENTICATED");
        assertThat(result)
                .bodyJson()
                .extractingPath("$.data.traceId")
                .asString()
                .matches("[0-9a-f]{32}");
    }

    @Test
    void CSRF_토큰_없이_로그인하면_403_FORBIDDEN이고_XSRF_TOKEN_쿠키값을_헤더로_보내면_된다() {
        String loginId = newLoginId();
        createUser(loginId, "OPERATOR", true, false);

        MvcTestResult withoutToken = mvc.post()
                .uri("/api/v1/user/login")
                .contentType(MediaType.APPLICATION_JSON)
                .content(body(loginId, PASSWORD))
                .exchange();
        assertThat(withoutToken).hasStatus(HttpStatus.FORBIDDEN);
        assertThat(withoutToken).bodyJson().extractingPath("$.code").isEqualTo("FORBIDDEN");

        // 프론트 흐름: 첫 요청에서 XSRF-TOKEN 쿠키를 받고, 쓰기 요청에 그 값을 X-XSRF-TOKEN 헤더로 보낸다
        Cookie xsrf = mvc.get().uri("/api/v1/user/me").exchange().getResponse().getCookie("XSRF-TOKEN");
        assertThat(xsrf).isNotNull();
        MvcTestResult withToken = mvc.post()
                .uri("/api/v1/user/login")
                .cookie(xsrf)
                .header("X-XSRF-TOKEN", xsrf.getValue())
                .contentType(MediaType.APPLICATION_JSON)
                .content(body(loginId, PASSWORD))
                .exchange();
        assertThat(withToken).hasStatus(HttpStatus.OK);
    }

    @Test
    void 로그아웃하면_세션이_끝나_같은_쿠키로_401() {
        String loginId = newLoginId();
        UUID id = createUser(loginId, "OPERATOR", true, false);
        Cookie session = login(loginId, PASSWORD).getResponse().getCookie("SESSION");

        MvcTestResult logout = mvc.post()
                .uri("/api/v1/user/logout")
                .cookie(session)
                .with(xsrf())
                .exchange();

        assertThat(logout).hasStatus(HttpStatus.OK);
        assertThat(logout).bodyJson().extractingPath("$.code").isEqualTo("OK");
        assertThat(sessionCount(id)).isZero();
        assertThat(mvc.get().uri("/api/v1/user/me").cookie(session).exchange()).hasStatus(HttpStatus.UNAUTHORIZED);
    }

    @Test
    void INV80_로그인한_뒤_tokens_valid_after가_기록되면_세션을_끊고_401() {
        String loginId = newLoginId();
        UUID id = createUser(loginId, "OPERATOR", true, false);
        Cookie session = login(loginId, PASSWORD).getResponse().getCookie("SESSION");
        jdbc.sql("UPDATE auth.users SET tokens_valid_after = now() + interval '1 second' WHERE id = :id")
                .param("id", id)
                .update();

        MvcTestResult result = mvc.get().uri("/api/v1/user/me").cookie(session).exchange();

        assertThat(result).hasStatus(HttpStatus.UNAUTHORIZED);
        assertThat(result).bodyJson().extractingPath("$.code").isEqualTo("UNAUTHENTICATED");
        assertThat(sessionCount(id)).isZero();
    }

    @Test
    void INV80_tokens_valid_after보다_나중에_로그인한_세션은_쓸_수_있다() {
        String loginId = newLoginId();
        UUID id = createUser(loginId, "OPERATOR", true, false);
        jdbc.sql("UPDATE auth.users SET tokens_valid_after = now() WHERE id = :id")
                .param("id", id)
                .update();
        Cookie session = login(loginId, PASSWORD).getResponse().getCookie("SESSION");

        assertThat(mvc.get().uri("/api/v1/user/me").cookie(session).exchange()).hasStatus(HttpStatus.OK);
    }

    @Test
    void 로그인한_뒤_사용_중지되거나_삭제되면_401() {
        String inactiveId = newLoginId();
        UUID inactive = createUser(inactiveId, "OPERATOR", true, false);
        Cookie inactiveSession = login(inactiveId, PASSWORD).getResponse().getCookie("SESSION");
        String deletedId = newLoginId();
        UUID deleted = createUser(deletedId, "OPERATOR", true, false);
        Cookie deletedSession = login(deletedId, PASSWORD).getResponse().getCookie("SESSION");

        jdbc.sql("UPDATE auth.users SET is_active = false WHERE id = :id")
                .param("id", inactive)
                .update();
        jdbc.sql("UPDATE auth.users SET deleted_at = now(), deleted_by = id WHERE id = :id")
                .param("id", deleted)
                .update();

        assertThat(mvc.get().uri("/api/v1/user/me").cookie(inactiveSession).exchange())
                .hasStatus(HttpStatus.UNAUTHORIZED);
        assertThat(mvc.get().uri("/api/v1/user/me").cookie(deletedSession).exchange())
                .hasStatus(HttpStatus.UNAUTHORIZED);
    }

    @Test
    void 비밀번호를_바꿔야_하면_내_정보와_로그아웃만_되고_나머지는_403_PASSWORD_CHANGE_REQUIRED() {
        String loginId = newLoginId();
        createUser(loginId, "OPERATOR", true, true);
        MvcTestResult login = login(loginId, PASSWORD);
        Cookie session = login.getResponse().getCookie("SESSION");
        assertThat(login).bodyJson().extractingPath("$.data.mustChangePassword").isEqualTo(true);

        MvcTestResult me = mvc.get().uri("/api/v1/user/me").cookie(session).exchange();
        MvcTestResult other = mvc.get().uri("/api/v1/product").cookie(session).exchange();
        MvcTestResult logout = mvc.post()
                .uri("/api/v1/user/logout")
                .cookie(session)
                .with(xsrf())
                .exchange();

        assertThat(me).hasStatus(HttpStatus.OK);
        assertThat(other).hasStatus(HttpStatus.FORBIDDEN);
        assertThat(other).bodyJson().extractingPath("$.code").isEqualTo("PASSWORD_CHANGE_REQUIRED");
        assertThat(logout).hasStatus(HttpStatus.OK);
    }

    @Test
    void 로그인_전에_있던_세션은_로그인하면_ID가_바뀐다() {
        String loginId = newLoginId();
        createUser(loginId, "OPERATOR", true, false);
        Cookie before = login(loginId, PASSWORD).getResponse().getCookie("SESSION");

        MvcTestResult again = mvc.post()
                .uri("/api/v1/user/login")
                .cookie(before)
                .with(xsrf())
                .contentType(MediaType.APPLICATION_JSON)
                .content(body(loginId, PASSWORD))
                .exchange();

        Cookie after = again.getResponse().getCookie("SESSION");
        assertThat(after).isNotNull();
        assertThat(after.getValue()).isNotEqualTo(before.getValue());
        assertThat(mvc.get().uri("/api/v1/user/me").cookie(before).exchange()).hasStatus(HttpStatus.UNAUTHORIZED);
        assertThat(mvc.get().uri("/api/v1/user/me").cookie(after).exchange()).hasStatus(HttpStatus.OK);
    }

    private MvcTestResult login(String loginId, String password) {
        return mvc.post()
                .uri("/api/v1/user/login")
                .with(xsrf())
                .contentType(MediaType.APPLICATION_JSON)
                .content(body(loginId, password))
                .exchange();
    }

    /**
     * 프론트처럼 {@code XSRF-TOKEN} 쿠키와 같은 값을 {@code X-XSRF-TOKEN} 헤더로 보낸다. 스프링 테스트의 {@code csrf()}는 보안 필터의 토큰
     * 저장소를 바꿔 버려 실제 쿠키 발급을 검사할 수 없어서 쓰지 않는다.
     */
    private static RequestPostProcessor xsrf() {
        String token = UUID.randomUUID().toString();
        return request -> {
            List<Cookie> cookies =
                    new ArrayList<>(request.getCookies() == null ? List.of() : List.of(request.getCookies()));
            cookies.add(new Cookie("XSRF-TOKEN", token));
            request.setCookies(cookies.toArray(Cookie[]::new));
            request.addHeader("X-XSRF-TOKEN", token);
            return request;
        };
    }

    private static String body(String loginId, String password) {
        return "{\"loginId\":\"" + loginId + "\",\"password\":\"" + password + "\"}";
    }

    private static String newLoginId() {
        return "u" + UUID.randomUUID().toString().substring(0, 8);
    }

    private UUID createUser(
            String loginId, String role, boolean active, boolean mustChangePassword, String... permissions) {
        UUID id = jdbc.sql("""
                        INSERT INTO auth.users (login_id, name, password_hash, is_active, must_change_password, created_by)
                        VALUES (:loginId, '테스트', :hash, :active, :mustChange, uuidv7())
                        RETURNING id
                        """)
                .param("loginId", loginId)
                .param("hash", passwordEncoder.encode(PASSWORD))
                .param("active", active)
                .param("mustChange", mustChangePassword)
                .query(UUID.class)
                .single();
        jdbc.sql("INSERT INTO auth.user_roles (user_id, role_id) SELECT :id, id FROM auth.roles WHERE code = :role")
                .param("id", id)
                .param("role", role)
                .update();
        for (String permission : permissions) {
            jdbc.sql("INSERT INTO auth.user_permissions (user_id, permission) VALUES (:id, :permission)")
                    .param("id", id)
                    .param("permission", permission)
                    .update();
        }
        return id;
    }

    private boolean lastLoginAtIsSet(UUID id) {
        return jdbc.sql("SELECT last_login_at IS NOT NULL FROM auth.users WHERE id = :id")
                .param("id", id)
                .query(Boolean.class)
                .single();
    }

    private int sessionCount(UUID id) {
        return jdbc.sql("SELECT count(*) FROM auth.spring_session WHERE principal_name = :id")
                .param("id", id.toString())
                .query(Integer.class)
                .single();
    }
}
