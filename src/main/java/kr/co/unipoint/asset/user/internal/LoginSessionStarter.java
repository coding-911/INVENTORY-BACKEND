package kr.co.unipoint.asset.user.internal;

import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContext;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.web.authentication.session.SessionAuthenticationStrategy;
import org.springframework.security.web.context.SecurityContextRepository;

/**
 * 로그인에 성공한 사람의 세션을 시작한다. 스프링 폼 로그인이 하는 일을 JSON 로그인 API에서 그대로 한다.
 *
 * <ol>
 *   <li>로그인 전 세션이 있었으면 세션 ID를 바꾼다(세션 고정 공격 방지).
 *   <li>CSRF 토큰을 새로 바꾼다.
 *   <li>로그인한 사람을 세션에 저장한다.
 * </ol>
 */
public class LoginSessionStarter {

    private final SessionAuthenticationStrategy sessionStrategy;
    private final SecurityContextRepository securityContexts;

    LoginSessionStarter(SessionAuthenticationStrategy sessionStrategy, SecurityContextRepository securityContexts) {
        this.sessionStrategy = sessionStrategy;
        this.securityContexts = securityContexts;
    }

    public void start(LoginUser user, HttpServletRequest request, HttpServletResponse response) {
        Authentication authentication =
                UsernamePasswordAuthenticationToken.authenticated(user, null, user.authorities());
        sessionStrategy.onAuthentication(authentication, request, response);
        CsrfCookieFilter.issue(request); // 바꾼 CSRF 토큰을 로그인 응답의 쿠키로 바로 준다
        SecurityContext context = SecurityContextHolder.createEmptyContext();
        context.setAuthentication(authentication);
        SecurityContextHolder.setContext(context);
        securityContexts.saveContext(context, request, response);
    }
}
