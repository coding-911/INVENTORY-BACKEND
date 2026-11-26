package kr.co.unipoint.asset.cost.web;

import jakarta.validation.Valid;
import java.util.List;
import kr.co.unipoint.asset.common.api.ApiResponse;
import kr.co.unipoint.asset.cost.internal.CurrencyService;
import kr.co.unipoint.asset.cost.web.request.CurrencyCreateRequest;
import kr.co.unipoint.asset.cost.web.request.CurrencyUpdateRequest;
import kr.co.unipoint.asset.cost.web.response.CurrencyResponse;
import org.springframework.http.HttpStatus;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

/**
 * 통화 목록·추가·수정 (API 목록 "통화 목록", "통화 추가", "통화 수정"). 목록은 로그인한 누구나(금액이 아닌 코드 표), 추가·수정은 관리자만 (권한
 * 매트릭스 3.1·3.3). 삭제 API는 없다. 금액 기록이 참조하므로 쓰지 않으면 끈다 (API 명세서 1.9).
 */
@RestController
@RequestMapping("/api/v1/cost/currency")
class CurrencyController {

    private final CurrencyService currencyService;

    CurrencyController(CurrencyService currencyService) {
        this.currencyService = currencyService;
    }

    @GetMapping
    ApiResponse<List<CurrencyResponse>> list(@RequestParam(required = false) Boolean isActive) {
        return ApiResponse.ok(currencyService.list(isActive).stream()
                .map(CurrencyResponse::from)
                .toList());
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    @PreAuthorize("hasRole('ADMIN')")
    ApiResponse<CurrencyResponse> add(@Valid @RequestBody CurrencyCreateRequest request) {
        return ApiResponse.created(CurrencyResponse.from(currencyService.add(
                request.code(),
                request.name(),
                request.minorUnit().shortValue(),
                Boolean.TRUE.equals(request.isActive()))));
    }

    @PatchMapping("/{code}")
    @PreAuthorize("hasRole('ADMIN')")
    ApiResponse<CurrencyResponse> update(@PathVariable String code, @Valid @RequestBody CurrencyUpdateRequest request) {
        return ApiResponse.ok(CurrencyResponse.from(currencyService.update(code, request.name(), request.isActive())));
    }
}
