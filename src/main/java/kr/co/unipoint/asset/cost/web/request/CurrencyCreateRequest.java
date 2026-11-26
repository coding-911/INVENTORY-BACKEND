package kr.co.unipoint.asset.cost.web.request;

import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

/**
 * 통화 추가 요청 (API 목록 "통화 추가").
 *
 * @param code ISO 4217 코드. 영문 대문자 3자(예: {@code EUR})
 * @param name 최대 50자({@code varchar(50)})
 * @param minorUnit 소수 자리. ISO 4217의 소수 자리는 0~4다
 * @param isActive 없으면 false(꺼진 채로 추가)
 */
public record CurrencyCreateRequest(
        @NotNull @Pattern(regexp = "[A-Z]{3}", message = "영문 대문자 3자로 넣어 주세요")
        String code,

        @NotBlank @Size(max = 50) String name,
        @NotNull @Min(0) @Max(4) Integer minorUnit,
        Boolean isActive) {}
