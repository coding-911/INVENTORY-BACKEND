package kr.co.unipoint.asset.common.web;

import java.util.ArrayList;
import java.util.List;
import java.util.Locale;
import kr.co.unipoint.asset.common.api.ApiResponse;
import kr.co.unipoint.asset.common.api.BusinessException;
import kr.co.unipoint.asset.common.api.ErrorCode;
import kr.co.unipoint.asset.common.api.ErrorDetail;
import kr.co.unipoint.asset.common.api.ErrorDetail.FieldViolation;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.slf4j.MDC;
import org.springframework.context.MessageSourceResolvable;
import org.springframework.dao.OptimisticLockingFailureException;
import org.springframework.http.ResponseEntity;
import org.springframework.http.converter.HttpMessageNotReadableException;
import org.springframework.validation.Errors;
import org.springframework.validation.FieldError;
import org.springframework.web.HttpMediaTypeException;
import org.springframework.web.HttpRequestMethodNotSupportedException;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.MissingRequestHeaderException;
import org.springframework.web.bind.MissingServletRequestParameterException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.web.method.annotation.HandlerMethodValidationException;
import org.springframework.web.method.annotation.MethodArgumentTypeMismatchException;
import org.springframework.web.servlet.resource.NoResourceFoundException;

/**
 * 모든 오류 응답을 만드는 곳 (docs/dev/conventions.md 7절, docs/api/api-spec.md 1.4).
 *
 * <p>입력 항목 오류의 {@code code}는 검사 이름(Bean Validation 제약 이름, Spring 바인딩 코드)을 대문자 스네이크로 바꾼 것이다. 예:
 * {@code NotNull} → {@code NOT_NULL}, {@code typeMismatch} → {@code TYPE_MISMATCH}.
 */
@RestControllerAdvice
class GlobalExceptionHandler {

    private static final Logger log = LoggerFactory.getLogger(GlobalExceptionHandler.class);

    @ExceptionHandler(BusinessException.class)
    ResponseEntity<ApiResponse<ErrorDetail>> handleBusiness(BusinessException e) {
        return respond(e.errorCode(), e.getMessage(), e.invariant(), List.of(), e.details());
    }

    /** {@code @Valid @RequestBody} 검사 실패. */
    @ExceptionHandler(MethodArgumentNotValidException.class)
    ResponseEntity<ApiResponse<ErrorDetail>> handleBodyInvalid(MethodArgumentNotValidException e) {
        return validationFailed(violations(e.getBindingResult()));
    }

    /** 경로·쿼리 파라미터 등 메서드 인자 검사 실패. */
    @ExceptionHandler(HandlerMethodValidationException.class)
    ResponseEntity<ApiResponse<ErrorDetail>> handleMethodInvalid(HandlerMethodValidationException e) {
        List<FieldViolation> violations = new ArrayList<>();
        e.getParameterValidationResults().forEach(result -> {
            if (result instanceof Errors errors) {
                violations.addAll(violations(errors));
                return;
            }
            String name = result.getMethodParameter().getParameterName();
            result.getResolvableErrors().forEach(error -> violations.add(violation(name, error)));
        });
        return validationFailed(violations);
    }

    /** 형식이 맞지 않는 값. 예: UUID가 아닌 id (docs/api/api-spec.md 1.13). */
    @ExceptionHandler(MethodArgumentTypeMismatchException.class)
    ResponseEntity<ApiResponse<ErrorDetail>> handleTypeMismatch(MethodArgumentTypeMismatchException e) {
        return validationFailed(List.of(new FieldViolation(e.getName(), "TYPE_MISMATCH", "형식이 맞지 않습니다")));
    }

    @ExceptionHandler(MissingServletRequestParameterException.class)
    ResponseEntity<ApiResponse<ErrorDetail>> handleMissingParameter(MissingServletRequestParameterException e) {
        return validationFailed(List.of(new FieldViolation(e.getParameterName(), "REQUIRED", "값이 필요합니다")));
    }

    /** 필수 헤더가 없음. 예: 업무 동작의 {@code Idempotency-Key} (docs/api/api-spec.md 1.5). */
    @ExceptionHandler(MissingRequestHeaderException.class)
    ResponseEntity<ApiResponse<ErrorDetail>> handleMissingHeader(MissingRequestHeaderException e) {
        return validationFailed(List.of(new FieldViolation(e.getHeaderName(), "REQUIRED", "값이 필요합니다")));
    }

    /** 요청 본문을 읽을 수 없음 (JSON 문법 오류, 타입이 다른 값 등). */
    @ExceptionHandler(HttpMessageNotReadableException.class)
    ResponseEntity<ApiResponse<ErrorDetail>> handleNotReadable(HttpMessageNotReadableException e) {
        return validationFailed(List.of());
    }

    /** 지원하지 않는 메서드·Content-Type. 공통 코드 표에 따로 없어 입력 오류로 돌려준다. */
    @ExceptionHandler({HttpRequestMethodNotSupportedException.class, HttpMediaTypeException.class})
    ResponseEntity<ApiResponse<ErrorDetail>> handleUnsupportedRequest(Exception e) {
        return validationFailed(List.of());
    }

    @ExceptionHandler(NoResourceFoundException.class)
    ResponseEntity<ApiResponse<ErrorDetail>> handleNoResource(NoResourceFoundException e) {
        return respond(ErrorCode.NOT_FOUND, null, null, List.of(), null);
    }

    /** 다른 사람이 먼저 수정함 (엔티티 {@code @Version}, docs/api/api-spec.md 1.6). */
    @ExceptionHandler(OptimisticLockingFailureException.class)
    ResponseEntity<ApiResponse<ErrorDetail>> handleOptimisticLock(OptimisticLockingFailureException e) {
        return respond(ErrorCode.VERSION_CONFLICT, null, null, List.of(), null);
    }

    /** 예상하지 못한 오류. 상세는 로그에만 남기고 응답에는 traceId만 준다. */
    @ExceptionHandler(Exception.class)
    ResponseEntity<ApiResponse<ErrorDetail>> handleUnexpected(Exception e) {
        log.error("처리하지 못한 오류", e);
        return respond(ErrorCode.INTERNAL_ERROR, null, null, List.of(), null);
    }

    private ResponseEntity<ApiResponse<ErrorDetail>> validationFailed(List<FieldViolation> violations) {
        return respond(ErrorCode.VALIDATION_FAILED, null, null, violations, null);
    }

    private ResponseEntity<ApiResponse<ErrorDetail>> respond(
            ErrorCode errorCode, String message, String invariant, List<FieldViolation> violations, Object details) {
        ErrorDetail detail = new ErrorDetail(invariant, violations, details, MDC.get(TraceIdFilter.MDC_KEY));
        String text = message != null ? message : errorCode.defaultMessage();
        return ResponseEntity.status(errorCode.status()).body(ApiResponse.error(errorCode, text, detail));
    }

    private static List<FieldViolation> violations(Errors errors) {
        List<FieldViolation> result = new ArrayList<>();
        for (FieldError error : errors.getFieldErrors()) {
            result.add(new FieldViolation(error.getField(), toCode(error.getCode()), error.getDefaultMessage()));
        }
        errors.getGlobalErrors()
                .forEach(error ->
                        result.add(new FieldViolation(null, toCode(error.getCode()), error.getDefaultMessage())));
        return result;
    }

    private static FieldViolation violation(String field, MessageSourceResolvable error) {
        String[] codes = error.getCodes();
        String code = codes == null || codes.length == 0 ? null : codes[codes.length - 1];
        return new FieldViolation(field, toCode(code), error.getDefaultMessage());
    }

    /** {@code NotNull} → {@code NOT_NULL}, {@code typeMismatch} → {@code TYPE_MISMATCH}. */
    static String toCode(String name) {
        if (name == null) {
            return "INVALID";
        }
        return name.replaceAll("([a-z0-9])([A-Z])", "$1_$2").toUpperCase(Locale.ROOT);
    }
}
