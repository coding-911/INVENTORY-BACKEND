package kr.co.unipoint.asset.common.api;

import com.fasterxml.jackson.annotation.JsonInclude;
import java.util.List;

/**
 * 오류 응답의 {@code data} (docs/api/api-spec.md 1.4).
 *
 * @param invariant 불변 조건 위반이면 INV 번호. 아니면 응답에서 빠진다
 * @param errors 입력 항목별 오류. 없으면 빈 목록
 * @param details 막힌 이유의 구체 내용. 오류 코드마다 모양이 다르고, 없으면 응답에서 빠진다
 * @param traceId 문의할 때 서버 로그를 찾는 번호
 */
public record ErrorDetail(
        @JsonInclude(JsonInclude.Include.NON_NULL) String invariant,
        List<FieldViolation> errors,
        @JsonInclude(JsonInclude.Include.NON_NULL) Object details,
        String traceId) {

    public ErrorDetail {
        errors = List.copyOf(errors);
    }

    /**
     * 입력 항목 하나의 오류.
     *
     * @param field 요청에서의 위치. 예: {@code lines[0].quantity}
     * @param code 검사 이름을 대문자 스네이크로. 예: {@code NOT_NULL}, {@code TYPE_MISMATCH}
     */
    public record FieldViolation(String field, String code, String message) {}
}
