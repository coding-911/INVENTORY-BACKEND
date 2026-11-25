package kr.co.unipoint.asset.common.api;

import org.springframework.http.HttpStatus;

/**
 * 오류 코드. 응답의 {@code code}로 이름을 그대로 보낸다 (docs/api/api-spec.md 1.4).
 *
 * <p>한 번 정한 이름은 바꾸지 않는다. 업무 코드는 그 코드를 쓰는 API를 만들 때 추가한다.
 */
public enum ErrorCode {
    VALIDATION_FAILED(HttpStatus.BAD_REQUEST, "입력 내용을 확인해 주세요"),
    CONFIRMATION_REQUIRED(HttpStatus.BAD_REQUEST, "확인이 필요합니다"),
    UNAUTHENTICATED(HttpStatus.UNAUTHORIZED, "로그인이 필요합니다"),
    LOGIN_FAILED(HttpStatus.UNAUTHORIZED, "아이디 또는 비밀번호가 맞지 않습니다"),
    PASSWORD_CHANGE_REQUIRED(HttpStatus.FORBIDDEN, "비밀번호를 바꾼 뒤 사용할 수 있습니다"),
    FORBIDDEN(HttpStatus.FORBIDDEN, "권한이 없습니다"),
    NOT_FOUND(HttpStatus.NOT_FOUND, "대상을 찾을 수 없습니다"),
    METHOD_NOT_ALLOWED(HttpStatus.METHOD_NOT_ALLOWED, "지원하지 않는 요청 방식입니다"),
    UNSUPPORTED_MEDIA_TYPE(HttpStatus.UNSUPPORTED_MEDIA_TYPE, "지원하지 않는 요청 형식입니다"),
    VERSION_CONFLICT(HttpStatus.CONFLICT, "다른 사용자가 먼저 수정했습니다. 다시 불러와 주세요"),
    REQUEST_IN_PROGRESS(HttpStatus.CONFLICT, "같은 요청을 처리하고 있습니다"),
    REQUEST_KEY_REUSED(HttpStatus.BAD_REQUEST, "이미 다른 요청에 쓴 키입니다"),
    INTERNAL_ERROR(HttpStatus.INTERNAL_SERVER_ERROR, "서버 오류가 발생했습니다");

    private final HttpStatus status;
    private final String defaultMessage;

    ErrorCode(HttpStatus status, String defaultMessage) {
        this.status = status;
        this.defaultMessage = defaultMessage;
    }

    public HttpStatus status() {
        return status;
    }

    public String defaultMessage() {
        return defaultMessage;
    }
}
