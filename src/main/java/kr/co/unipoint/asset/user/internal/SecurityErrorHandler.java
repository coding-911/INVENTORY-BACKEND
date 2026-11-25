package kr.co.unipoint.asset.user.internal;

import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.security.core.AuthenticationException;
import org.springframework.security.web.AuthenticationEntryPoint;
import org.springframework.security.web.access.AccessDeniedHandler;
import org.springframework.stereotype.Component;
import org.springframework.web.servlet.HandlerExceptionResolver;

/**
 * 보안 필터에서 난 오류(로그인 안 됨, 권한 없음, CSRF 토큰 없음)도 공통 예외 처리기로 넘겨 같은 응답 형식으로 보낸다 (docs/api/api-spec.md
 * 1.4). 필터의 예외는 {@code @RestControllerAdvice}까지 가지 않아서 직접 넘긴다.
 */
@Component
class SecurityErrorHandler implements AuthenticationEntryPoint, AccessDeniedHandler {

    private final HandlerExceptionResolver resolver;

    SecurityErrorHandler(@Qualifier("handlerExceptionResolver") HandlerExceptionResolver resolver) {
        this.resolver = resolver;
    }

    @Override
    public void commence(
            HttpServletRequest request, HttpServletResponse response, AuthenticationException authException) {
        reject(request, response, authException);
    }

    @Override
    public void handle(
            HttpServletRequest request, HttpServletResponse response, AccessDeniedException accessDeniedException) {
        reject(request, response, accessDeniedException);
    }

    void reject(HttpServletRequest request, HttpServletResponse response, Exception exception) {
        resolver.resolveException(request, response, null, exception);
    }
}
