package kr.co.unipoint.asset.user.internal;

import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;
import org.springframework.security.core.AuthenticatedPrincipal;
import org.springframework.security.core.GrantedAuthority;
import org.springframework.security.core.authority.SimpleGrantedAuthority;

/**
 * 이번 요청의 로그인한 사람. 컨트롤러는 {@code @AuthenticationPrincipal LoginUser}로 받는다.
 *
 * <p>세션에 저장하지 않는다. 세션에는 {@link SessionUser}(ID·로그인 시각)만 있고, {@link SessionCheckFilter}가 요청마다 DB에서 계정을 읽어
 * 이것을 만든다. 그래서 역할·금액 권한은 항상 DB의 최신 값이다.
 *
 * @param roles {@code ADMIN}·{@code OPERATOR}·{@code VIEWER}
 * @param permissions {@code COST_VIEW}·{@code COST_EDIT}
 * @param loginAt 로그인한 시각(DB 시각)
 */
public record LoginUser(
        UUID id, String loginId, String name, List<String> roles, List<String> permissions, Instant loginAt)
        implements AuthenticatedPrincipal {

    public LoginUser {
        roles = List.copyOf(roles);
        permissions = List.copyOf(permissions);
    }

    @Override
    public String getName() {
        return id.toString();
    }

    /** 역할은 {@code ROLE_} 접두사를 붙이고({@code hasRole}), 금액 권한은 그대로 둔다({@code hasAuthority}). */
    public List<GrantedAuthority> authorities() {
        List<GrantedAuthority> result = new ArrayList<>();
        roles.forEach(role -> result.add(new SimpleGrantedAuthority("ROLE_" + role)));
        permissions.forEach(permission -> result.add(new SimpleGrantedAuthority(permission)));
        return result;
    }
}
