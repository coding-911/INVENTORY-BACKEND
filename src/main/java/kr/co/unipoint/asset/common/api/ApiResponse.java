package kr.co.unipoint.asset.common.api;

import com.fasterxml.jackson.annotation.JsonInclude;
import java.util.List;
import org.springframework.http.HttpStatus;

/**
 * 모든 API 응답의 틀. 성공·실패 모두 같은 모양이다 (docs/api/api-spec.md 1.4).
 *
 * @param status 실제 HTTP 상태와 항상 같다
 * @param code 성공은 {@code OK}, 실패는 {@link ErrorCode} 이름
 * @param data 성공이면 결과, 실패면 {@link ErrorDetail}
 * @param warnings 참고용 경고. 없으면 응답에서 빠진다
 */
public record ApiResponse<T>(
        int status,
        String code,
        String message,
        T data,
        @JsonInclude(JsonInclude.Include.NON_EMPTY) List<Warning> warnings) {

    public static final String OK_CODE = "OK";
    public static final String OK_MESSAGE = "정상 처리했습니다";

    public static <T> ApiResponse<T> ok(T data) {
        return success(HttpStatus.OK, data, List.of());
    }

    public static <T> ApiResponse<T> ok(T data, List<Warning> warnings) {
        return success(HttpStatus.OK, data, warnings);
    }

    /** 등록 성공. 컨트롤러는 HTTP 상태도 201로 보낸다. */
    public static <T> ApiResponse<T> created(T data) {
        return success(HttpStatus.CREATED, data, List.of());
    }

    public static ApiResponse<ErrorDetail> error(ErrorCode errorCode, String message, ErrorDetail detail) {
        return new ApiResponse<>(errorCode.status().value(), errorCode.name(), message, detail, List.of());
    }

    private static <T> ApiResponse<T> success(HttpStatus status, T data, List<Warning> warnings) {
        return new ApiResponse<>(status.value(), OK_CODE, OK_MESSAGE, data, List.copyOf(warnings));
    }

    /** 성공 응답에 붙는 참고용 경고. 예: 원가 미확인. */
    public record Warning(String code, String message) {}
}
