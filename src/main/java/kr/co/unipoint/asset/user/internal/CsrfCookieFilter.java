package kr.co.unipoint.asset.user.internal;

import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import java.io.IOException;
import org.springframework.security.web.csrf.CsrfToken;
import org.springframework.web.filter.OncePerRequestFilter;

/**
 * {@code XSRF-TOKEN} 쿠키가 없으면 이번 응답에 넣는다. 스프링은 토큰을 쓸 일이 생길 때만 만들어서, 그대로 두면 로그인 전 프론트가 토큰을 받을 길이
 * 없다. 쿠키가 이미 있으면 아무것도 하지 않는다.
 *
 * <p>빈으로 등록하지 않는다. {@link SecurityConfig}가 CSRF 필터 바로 뒤에 넣는다.
 */
class CsrfCookieFilter extends OncePerRequestFilter {

    @Override
    protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response, FilterChain chain)
            throws ServletException, IOException {
        issue(request);
        chain.doFilter(request, response);
    }

    /** 이 요청의 CSRF 토큰을 꺼내 쿠키가 없으면 만들게 한다. 로그인으로 토큰을 바꾼 뒤에도 부른다. */
    static void issue(HttpServletRequest request) {
        if (request.getAttribute(CsrfToken.class.getName()) instanceof CsrfToken token) {
            token.getToken();
        }
    }
}
