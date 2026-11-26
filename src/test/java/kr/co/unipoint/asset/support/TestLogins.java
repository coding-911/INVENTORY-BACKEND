package kr.co.unipoint.asset.support;

import jakarta.servlet.http.Cookie;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;
import org.springframework.http.MediaType;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.test.web.servlet.assertj.MockMvcTester;
import org.springframework.test.web.servlet.request.RequestPostProcessor;

/**
 * API 테스트용 로그인. 계정을 DB에 바로 넣고 실제 로그인 API로 세션 쿠키를 받는다. 그래서 권한 검사도 실제와 같이 요청마다 DB에서 역할의 권한을 읽어서 한다.
 */
public final class TestLogins {

    private static final String PASSWORD = "pw-1234";

    private final MockMvcTester mvc;
    private final JdbcClient jdbc;
    private final PasswordEncoder passwordEncoder;

    public TestLogins(MockMvcTester mvc, JdbcClient jdbc, PasswordEncoder passwordEncoder) {
        this.mvc = mvc;
        this.jdbc = jdbc;
        this.passwordEncoder = passwordEncoder;
    }

    /** 기본 역할({@code ADMIN}, {@code OPERATOR_BASIC} 등, 권한 매트릭스 1.5) 계정을 만들고 로그인한 세션 쿠키를 돌려준다. */
    public Cookie loginAs(String roleCode) {
        UUID roleId = jdbc.sql("SELECT id FROM auth.roles WHERE code = :code AND deleted_at IS NULL")
                .param("code", roleCode)
                .query(UUID.class)
                .single();
        return login(roleId, roleCode);
    }

    /**
     * 주어진 권한만 가진 역할을 새로 만들고 그 역할 계정으로 로그인한다. 권한 하나가 있고 없음에 따라 결과가 갈리는지 볼 때 쓴다(기본 역할에 없는
     * 조합).
     */
    public Cookie loginWithPermissions(String... permissions) {
        String code = "T_"
                + UUID.randomUUID().toString().replace("-", "").substring(0, 12).toUpperCase();
        UUID roleId = jdbc.sql("INSERT INTO auth.roles (code, name) VALUES (:code, :code) RETURNING id")
                .param("code", code)
                .query(UUID.class)
                .single();
        for (String permission : permissions) {
            jdbc.sql("INSERT INTO auth.role_permissions (role_id, permission_code) VALUES (:roleId, :permission)")
                    .param("roleId", roleId)
                    .param("permission", permission)
                    .update();
        }
        return login(roleId, code);
    }

    private Cookie login(UUID roleId, String roleCode) {
        String loginId = "t-" + UUID.randomUUID().toString().substring(0, 12);
        jdbc.sql("""
                        INSERT INTO auth.users (login_id, name, password_hash, is_active, must_change_password, role_id, created_by)
                        VALUES (:loginId, '테스트', :hash, true, false, :roleId, uuidv7())
                        """)
                .param("loginId", loginId)
                .param("hash", passwordEncoder.encode(PASSWORD))
                .param("roleId", roleId)
                .update();
        Cookie session = mvc.post()
                .uri("/api/v1/user/login")
                .with(xsrf())
                .contentType(MediaType.APPLICATION_JSON)
                .content("{\"loginId\":\"" + loginId + "\",\"password\":\"" + PASSWORD + "\"}")
                .exchange()
                .getResponse()
                .getCookie("SESSION");
        if (session == null) {
            throw new IllegalStateException("테스트 로그인 실패: " + roleCode);
        }
        return session;
    }

    /**
     * 쓰기 요청의 CSRF 토큰 (API 명세서 1.3). 프론트처럼 {@code XSRF-TOKEN} 쿠키와 같은 값을 {@code X-XSRF-TOKEN} 헤더로 보낸다(AuthApiTest와
     * 같은 방법).
     */
    public static RequestPostProcessor xsrf() {
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
}
