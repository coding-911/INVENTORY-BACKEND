package kr.co.unipoint.asset.user.internal;

import java.util.List;
import kr.co.unipoint.asset.common.api.ApiResponse;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.HttpMethod;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.security.config.annotation.method.configuration.EnableMethodSecurity;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.security.web.access.intercept.AuthorizationFilter;
import org.springframework.security.web.authentication.logout.LogoutSuccessHandler;
import org.springframework.security.web.authentication.session.ChangeSessionIdAuthenticationStrategy;
import org.springframework.security.web.authentication.session.CompositeSessionAuthenticationStrategy;
import org.springframework.security.web.context.DelegatingSecurityContextRepository;
import org.springframework.security.web.context.HttpSessionSecurityContextRepository;
import org.springframework.security.web.context.RequestAttributeSecurityContextRepository;
import org.springframework.security.web.context.SecurityContextRepository;
import org.springframework.security.web.csrf.CookieCsrfTokenRepository;
import org.springframework.security.web.csrf.CsrfAuthenticationStrategy;
import org.springframework.security.web.csrf.CsrfFilter;
import org.springframework.security.web.csrf.CsrfTokenRepository;
import org.springframework.session.web.http.CookieSerializer;
import org.springframework.session.web.http.DefaultCookieSerializer;
import tools.jackson.databind.json.JsonMapper;

/**
 * 세션 로그인 (API 명세서 1.3, 2026-11-25 OAuth2 + JWT에서 바꿈).
 *
 * <ul>
 *   <li>로그인하면 세션을 만들고 HttpOnly 쿠키({@code SESSION})로 주고받는다. 세션은 DB({@code auth.spring_session})에 두고 마지막 요청 뒤
 *       8시간이 지나면 끝난다({@code spring.session.timeout}).
 *   <li>로그인·로그아웃 외의 모든 API는 로그인이 필요하다. 권한별 제한은 각 모듈의 컨트롤러 메서드에 {@code @PreAuthorize}로
 *       붙인다(예: {@code hasAuthority('MASTER_MANAGE')}, 권한 코드로만 검사하고 {@code hasRole}은 쓰지 않는다, docs/rules/permissions.md 1.8). 막히면 403 {@code FORBIDDEN}. 요청 본문 검사가
 *       먼저 돌아서, 권한 없는 사람이 형식이 틀린 본문을 보내면 400이다.
 *   <li>CSRF: 쿠키를 자동으로 보내는 방식이라 쓰기 요청은 {@code XSRF-TOKEN} 쿠키 값을 {@code X-XSRF-TOKEN} 헤더로 함께 보내야 한다.
 * </ul>
 */
@Configuration
@EnableMethodSecurity
class SecurityConfig {

    static final String LOGIN_URL = "/api/v1/user/login";
    static final String LOGOUT_URL = "/api/v1/user/logout";

    /** 스프링 기본과 같은 저장소를 쓴다. 쿠키 이름 {@code XSRF-TOKEN}, 헤더 이름 {@code X-XSRF-TOKEN}. */
    private final CsrfTokenRepository csrfTokens = CookieCsrfTokenRepository.withHttpOnlyFalse();

    private final SecurityContextRepository securityContexts = new DelegatingSecurityContextRepository(
            new RequestAttributeSecurityContextRepository(), new HttpSessionSecurityContextRepository());

    @Bean
    SecurityFilterChain securityFilterChain(
            HttpSecurity http, SecurityErrorHandler errors, UserAccountStore store, JsonMapper json) {
        http.authorizeHttpRequests(requests -> requests.requestMatchers(HttpMethod.POST, LOGIN_URL)
                        .permitAll()
                        .requestMatchers("/error")
                        .permitAll()
                        .anyRequest()
                        .authenticated())
                .csrf(csrf -> csrf.spa().csrfTokenRepository(csrfTokens))
                .securityContext(context -> context.securityContextRepository(securityContexts))
                .requestCache(cache -> cache.disable())
                .exceptionHandling(exceptions ->
                        exceptions.authenticationEntryPoint(errors).accessDeniedHandler(errors))
                .logout(logout -> logout.logoutUrl(LOGOUT_URL).logoutSuccessHandler(logoutSuccess(json)))
                .addFilterBefore(new SessionCheckFilter(store, errors), AuthorizationFilter.class)
                .addFilterAfter(new CsrfCookieFilter(), CsrfFilter.class);
        return http.build();
    }

    /** 로그인 API가 세션을 시작할 때 쓴다. 보안 필터와 같은 CSRF·보안 정보 저장소를 써야 해서 여기서 만든다. */
    @Bean
    LoginSessionStarter loginSessionStarter() {
        return new LoginSessionStarter(
                new CompositeSessionAuthenticationStrategy(List.of(
                        new ChangeSessionIdAuthenticationStrategy(), new CsrfAuthenticationStrategy(csrfTokens))),
                securityContexts);
    }

    /**
     * 세션 쿠키 {@code SESSION}: HttpOnly(화면 스크립트가 못 읽음), SameSite=Lax(다른 사이트에서 보낸 쓰기 요청에 안 붙음), HTTPS 요청이면 Secure.
     * {@code server.servlet.session.cookie.http-only}를 줘도 스프링 부트 4.1이 자동으로 만든 쿠키 설정은 HttpOnly가 false였다(원인은
     * 확인하지 않음). 그래서 직접 만들고 AuthApiTest로 확인한다.
     */
    @Bean
    CookieSerializer sessionCookieSerializer() {
        DefaultCookieSerializer serializer = new DefaultCookieSerializer();
        serializer.setUseHttpOnlyCookie(true);
        serializer.setSameSite("Lax");
        return serializer;
    }

    @Bean
    PasswordEncoder passwordEncoder() {
        return new BCryptPasswordEncoder();
    }

    private static LogoutSuccessHandler logoutSuccess(JsonMapper json) {
        return (request, response, authentication) -> {
            response.setStatus(HttpStatus.OK.value());
            response.setContentType(MediaType.APPLICATION_JSON_VALUE);
            response.setCharacterEncoding("UTF-8");
            json.writeValue(response.getWriter(), ApiResponse.ok(null));
        };
    }
}
