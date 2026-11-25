package kr.co.unipoint.asset.user.web.request;

import jakarta.validation.constraints.NotBlank;

/** 로그인 요청. 비밀번호 규칙은 없다 (#100). */
public record LoginRequest(
        @NotBlank String loginId, @NotBlank String password) {}
