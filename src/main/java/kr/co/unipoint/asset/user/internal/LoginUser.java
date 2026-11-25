package kr.co.unipoint.asset.user.internal;

import java.io.Serial;
import java.io.Serializable;
import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;
import org.springframework.security.core.AuthenticatedPrincipal;
import org.springframework.security.core.GrantedAuthority;
import org.springframework.security.core.authority.SimpleGrantedAuthority;

/**
 * 세션에 저장하는 로그인한 사람. 세션 테이블에 직렬화해 저장한다.
 *
 * <p>{@link #getName()}은 사용자 ID라서 세션 테이블의 {@code principal_name}에 사용자 ID가 들어간다.
 *
 * @param roles {@code ADMIN}·{@code OPERATOR}·{@code VIEWER}
 * @param permissions {@code COST_VIEW}·{@code COST_EDIT}
 * @param loginAt 로그인한 시각(DB 시각). {@code users.tokens_valid_after}보다 이르면 세션을 끊는다 (INV-80)
 */
public record LoginUser(
        UUID id, String loginId, String name, List<String> roles, List<String> permissions, Instant loginAt)
        implements AuthenticatedPrincipal, Serializable {

    @Serial
    private static final long serialVersionUID = 1L;

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
