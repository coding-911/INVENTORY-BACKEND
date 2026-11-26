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
 * API 테스트용 로그인. 계정을 DB에 바로 넣고 실제 로그인 API로 세션 쿠키를 받는다. 그래서 권한 검사도 실제와 같이 요청마다 DB의 역할을 읽어서 한다.
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

    /** 역할 하나와 금액 권한을 가진 사용 중인 계정을 만들고 로그인한 세션 쿠키를 돌려준다. */
    public Cookie loginAs(String role, String... permissions) {
        String loginId = "t-" + UUID.randomUUID().toString().substring(0, 12);
        UUID id = jdbc.sql("""
                        INSERT INTO auth.users (login_id, name, password_hash, is_active, must_change_password, created_by)
                        VALUES (:loginId, '테스트', :hash, true, false, uuidv7())
                        RETURNING id
                        """)
                .param("loginId", loginId)
                .param("hash", passwordEncoder.encode(PASSWORD))
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
        Cookie session = mvc.post()
                .uri("/api/v1/user/login")
                .with(xsrf())
                .contentType(MediaType.APPLICATION_JSON)
                .content("{\"loginId\":\"" + loginId + "\",\"password\":\"" + PASSWORD + "\"}")
                .exchange()
                .getResponse()
                .getCookie("SESSION");
        if (session == null) {
            throw new IllegalStateException("테스트 로그인 실패: " + role);
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
