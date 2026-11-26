package kr.co.unipoint.asset.user.web.response;

import java.util.List;
import java.util.UUID;
import kr.co.unipoint.asset.user.internal.LoginService.RoleRef;
import kr.co.unipoint.asset.user.internal.LoginService.UserProfile;

/**
 * 응답 객체 {@code Me} (docs/api/api-spec.md 3절, 1.14). 프론트는 permissions로 메뉴를 그린다.
 *
 * @param role 계정의 역할 하나 (2026-11-26 roles[]에서 바꿈, #106)
 * @param permissions 역할의 권한 코드, 권한 목록 순서
 * @param mustChangePassword true면 비밀번호를 바꿀 때까지 내 정보·비밀번호 변경·로그아웃만 쓸 수 있다
 */
public record MeResponse(
        UUID id, String loginId, String name, Role role, List<String> permissions, boolean mustChangePassword) {

    public static MeResponse from(UserProfile profile) {
        return new MeResponse(
                profile.id(),
                profile.loginId(),
                profile.name(),
                Role.from(profile.role()),
                profile.permissions(),
                profile.mustChangePassword());
    }

    public record Role(UUID id, String code, String name) {

        static Role from(RoleRef role) {
            return new Role(role.id(), role.code(), role.name());
        }
    }
}
