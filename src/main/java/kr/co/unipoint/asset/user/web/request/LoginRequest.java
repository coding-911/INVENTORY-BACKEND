package kr.co.unipoint.asset.user.web.request;

import jakarta.validation.constraints.NotBlank;

/**
 * 로그인 요청. 비밀번호 규칙은 없다 (#100). 72바이트를 넘는 비밀번호도 비교는 예외 없이 앞 72바이트로 하므로 길이를 따로 보지 않는다. 그래서 로그인
 * 실패는 계속 401 {@code LOGIN_FAILED} 하나다.
 */
public record LoginRequest(
        @NotBlank String loginId, @NotBlank String password) {}
