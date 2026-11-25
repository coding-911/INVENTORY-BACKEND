package kr.co.unipoint.asset.user.web;

import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import jakarta.servlet.http.HttpSession;
import jakarta.validation.Valid;
import kr.co.unipoint.asset.common.api.ApiResponse;
import kr.co.unipoint.asset.user.internal.LoginService;
import kr.co.unipoint.asset.user.internal.LoginService.LoginResult;
import kr.co.unipoint.asset.user.internal.LoginSessionStarter;
import kr.co.unipoint.asset.user.internal.LoginUser;
import kr.co.unipoint.asset.user.web.request.ChangePasswordRequest;
import kr.co.unipoint.asset.user.web.request.LoginRequest;
import kr.co.unipoint.asset.user.web.response.MeResponse;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * 로그인, 내 정보, 본인 비밀번호 변경 (API 목록 "로그인·로그아웃", "내 정보", "본인 비밀번호 변경"). 로그아웃({@code POST /api/v1/user/logout})은 스프링 시큐리티가 처리한다.
 */
@RestController
@RequestMapping("/api/v1/user")
class AuthController {

    private final LoginService loginService;
    private final LoginSessionStarter sessions;

    AuthController(LoginService loginService, LoginSessionStarter sessions) {
        this.loginService = loginService;
        this.sessions = sessions;
    }

    /** 성공하면 세션 쿠키를 주고 내 정보를 돌려준다. 실패는 401 {@code LOGIN_FAILED}. */
    @PostMapping("/login")
    ApiResponse<MeResponse> login(
            @Valid @RequestBody LoginRequest request,
            HttpServletRequest httpRequest,
            HttpServletResponse httpResponse) {
        LoginResult result = loginService.login(request.loginId(), request.password());
        sessions.start(result.user(), httpRequest, httpResponse);
        return ApiResponse.ok(MeResponse.from(result.profile()));
    }

    @GetMapping("/me")
    ApiResponse<MeResponse> me(@AuthenticationPrincipal LoginUser user) {
        return ApiResponse.ok(MeResponse.from(loginService.me(user.id())));
    }

    /**
     * 본인 비밀번호 변경. 바꾸면 이 사용자의 모든 세션이 끊기므로(INV-80) 이 세션도 여기서 끝내고, 프론트는 새 비밀번호로 다시 로그인한다. 지금 비밀번호가
     * 틀리면 400 {@code PASSWORD_MISMATCH}이고 세션은 그대로다.
     */
    @PostMapping("/me/password")
    ApiResponse<Void> changePassword(
            @AuthenticationPrincipal LoginUser user,
            @Valid @RequestBody ChangePasswordRequest request,
            HttpServletRequest httpRequest) {
        loginService.changePassword(user.id(), request.currentPassword(), request.newPassword());
        HttpSession session = httpRequest.getSession(false);
        if (session != null) {
            session.invalidate();
        }
        SecurityContextHolder.clearContext();
        return ApiResponse.ok(null);
    }
}
