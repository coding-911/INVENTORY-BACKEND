package kr.co.unipoint.asset.common.api;

/**
 * 업무 규칙 위반. 공통 예외 처리기가 {@link ErrorCode}의 HTTP 상태로 응답을 만든다 (docs/dev/conventions.md 7절).
 */
public class BusinessException extends RuntimeException {

    private final ErrorCode errorCode;
    private final String invariant;
    private final Object details;

    public BusinessException(ErrorCode errorCode) {
        this(errorCode, null, null, null);
    }

    public BusinessException(ErrorCode errorCode, Object details) {
        this(errorCode, null, null, details);
    }

    /**
     * @param message 사용자에게 보일 메시지. null이면 오류 코드의 기본 메시지
     * @param invariant 위반한 불변 조건 번호(예: {@code INV-03}). 없으면 null
     * @param details 오류 상세의 {@code details}. 없으면 null
     */
    public BusinessException(ErrorCode errorCode, String message, String invariant, Object details) {
        super(message != null ? message : errorCode.defaultMessage());
        this.errorCode = errorCode;
        this.invariant = invariant;
        this.details = details;
    }

    public ErrorCode errorCode() {
        return errorCode;
    }

    public String invariant() {
        return invariant;
    }

    public Object details() {
        return details;
    }
}
