package kr.co.unipoint.asset.user.web.request;

import jakarta.validation.constraints.NotBlank;

/** 본인 비밀번호 변경 요청. 비밀번호 규칙은 없고 빈 값만 막는다 (#100). 길이는 해시 한도({@link PasswordMaxBytes})만 본다. */
public record ChangePasswordRequest(
        @NotBlank @PasswordMaxBytes String currentPassword,
        @NotBlank @PasswordMaxBytes String newPassword) {}
