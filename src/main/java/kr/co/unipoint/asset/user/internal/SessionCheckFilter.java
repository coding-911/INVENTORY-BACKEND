package kr.co.unipoint.asset.user.internal;

import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import jakarta.servlet.http.HttpSession;
import java.io.IOException;
import java.util.Optional;
import kr.co.unipoint.asset.common.api.BusinessException;
import kr.co.unipoint.asset.common.api.ErrorCode;
import kr.co.unipoint.asset.user.internal.UserAccountStore.Account;
import org.springframework.http.HttpMethod;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContext;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.web.servlet.util.matcher.PathPatternRequestMatcher;
import org.springframework.security.web.util.matcher.OrRequestMatcher;
import org.springframework.security.web.util.matcher.RequestMatcher;
import org.springframework.web.filter.OncePerRequestFilter;

/**
 * 로그인한 요청마다 계정을 DB에서 다시 읽는다 (API 명세서 1.3·1.14, INV-80, ADR-17).
 *
 * <ul>
 *   <li>세션에는 사용자 ID와 로그인 시각({@link SessionUser})만 있다. 역할·금액 권한은 여기서 읽어 이번 요청의 {@link LoginUser}로 만든다. 이
 *       값은 세션에 저장하지 않는다.
 *   <li>계정이 삭제·사용 중지됐거나, 로그인한 뒤 역할·권한·비밀번호 등이 바뀌어 {@code tokens_valid_after}가 로그인 시각보다 늦으면 세션을
 *       끊고 401 {@code UNAUTHENTICATED}. 다시 로그인하면 바뀐 권한으로 일한다.
 *   <li>비밀번호를 바꿔야 하는 사용자는 내 정보·본인 비밀번호 변경만 쓸 수 있고 나머지는 403 {@code PASSWORD_CHANGE_REQUIRED}. 로그아웃은
 *       이 필터 앞에서 끝난다.
 * </ul>
 *
 * <p>빈으로 등록하지 않는다. 빈이면 서블릿 필터로도 한 번 더 걸리기 때문이다. {@link SecurityConfig}가 보안 필터 안에 넣는다.
 */
class SessionCheckFilter extends OncePerRequestFilter {

    private static final RequestMatcher ALLOWED_WHILE_PASSWORD_CHANGE = new OrRequestMatcher(
            PathPatternRequestMatcher.withDefaults().matcher(HttpMethod.GET, "/api/v1/user/me"),
            PathPatternRequestMatcher.withDefaults().matcher(HttpMethod.POST, "/api/v1/user/me/password"));

    private final UserAccountStore store;
    private final SecurityErrorHandler errors;

    SessionCheckFilter(UserAccountStore store, SecurityErrorHandler errors) {
        this.store = store;
        this.errors = errors;
    }

    @Override
    protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response, FilterChain chain)
            throws ServletException, IOException {
        Authentication authentication = SecurityContextHolder.getContext().getAuthentication();
        if (authentication == null || !(authentication.getPrincipal() instanceof SessionUser sessionUser)) {
            chain.doFilter(request, response);
            return;
        }
        Optional<Account> account = store.findById(sessionUser.id());
        if (account.isEmpty() || !account.get().allowsSessionFrom(sessionUser.loginAt())) {
            HttpSession session = request.getSession(false);
            if (session != null) {
                session.invalidate();
            }
            SecurityContextHolder.clearContext();
            errors.reject(request, response, new BusinessException(ErrorCode.UNAUTHENTICATED));
            return;
        }
        if (account.get().mustChangePassword() && !ALLOWED_WHILE_PASSWORD_CHANGE.matches(request)) {
            errors.reject(request, response, new BusinessException(ErrorCode.PASSWORD_CHANGE_REQUIRED));
            return;
        }
        // 이번 요청에만 쓰는 보안 정보로 바꾼다. 세션에 저장된 것(SessionUser)은 건드리지 않는다
        LoginUser user = account.get().toLoginUser(sessionUser.loginAt());
        SecurityContext context = SecurityContextHolder.createEmptyContext();
        context.setAuthentication(UsernamePasswordAuthenticationToken.authenticated(user, null, user.authorities()));
        SecurityContextHolder.setContext(context);
        chain.doFilter(request, response);
    }
}
