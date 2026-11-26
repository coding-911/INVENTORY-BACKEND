package kr.co.unipoint.asset.cost.web.request;

import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

/**
 * 통화 수정 요청 (API 목록 "통화 수정"). 바꿀 항목만 보낸다. 코드·소수 자리는 금액 기록이 기대므로 바꾸지 않는다. 코드 표라 {@code version}을
 * 받지 않는다 (API 명세서 1.9).
 *
 * @param name 보내면 비어 있으면 안 된다
 * @param isActive 원화는 끌 수 없다
 */
public record CurrencyUpdateRequest(
        @Size(max = 50) @Pattern(regexp = "(?s).*\\S.*", message = "비어 있을 수 없습니다")
        String name,

        Boolean isActive) {}
