package kr.co.unipoint.asset.user.web.response;

import java.util.List;
import java.util.UUID;
import kr.co.unipoint.asset.user.internal.LoginService.UserProfile;

/**
 * 응답 객체 {@code Me} (docs/api/api-spec.md 3절, 1.14).
 *
 * @param roles {@code ADMIN}·{@code OPERATOR}·{@code VIEWER}
 * @param permissions {@code COST_VIEW}·{@code COST_EDIT}
 * @param mustChangePassword true면 비밀번호를 바꿀 때까지 내 정보·비밀번호 변경·로그아웃만 쓸 수 있다
 */
public record MeResponse(
        UUID id,
        String loginId,
        String name,
        List<String> roles,
        List<String> permissions,
        boolean mustChangePassword) {

    public static MeResponse from(UserProfile profile) {
        return new MeResponse(
                profile.id(),
                profile.loginId(),
                profile.name(),
                profile.roles(),
                profile.permissions(),
                profile.mustChangePassword());
    }
}
