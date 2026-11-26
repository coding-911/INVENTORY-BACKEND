package kr.co.unipoint.asset.user.internal;

import java.time.Instant;
import java.util.List;
import java.util.UUID;
import org.springframework.security.core.AuthenticatedPrincipal;
import org.springframework.security.core.GrantedAuthority;
import org.springframework.security.core.authority.SimpleGrantedAuthority;

/**
 * 이번 요청의 로그인한 사람. 컨트롤러는 {@code @AuthenticationPrincipal LoginUser}로 받는다.
 *
 * <p>세션에 저장하지 않는다. 세션에는 {@link SessionUser}(ID·로그인 시각)만 있고, {@link SessionCheckFilter}가 요청마다 DB에서 계정을 읽어
 * 이것을 만든다. 그래서 권한은 항상 DB의 최신 값이다(역할의 권한을 바꾸면 다음 요청부터 적용, 권한 매트릭스 R5).
 *
 * @param permissions 계정 역할의 권한 코드({@link kr.co.unipoint.asset.user.Permission})
 * @param loginAt 로그인한 시각(DB 시각)
 */
public record LoginUser(UUID id, String loginId, String name, List<String> permissions, Instant loginAt)
        implements AuthenticatedPrincipal {

    public LoginUser {
        permissions = List.copyOf(permissions);
    }

    @Override
    public String getName() {
        return id.toString();
    }

    /** 권한 코드를 그대로 넣는다({@code hasAuthority}). 역할은 넣지 않는다: 코드는 역할이 아니라 권한으로 검사한다. */
    public List<GrantedAuthority> authorities() {
        return permissions.stream()
                .<GrantedAuthority>map(SimpleGrantedAuthority::new)
                .toList();
    }
}
