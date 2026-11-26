package kr.co.unipoint.asset.cost.web.response;

import kr.co.unipoint.asset.cost.internal.Currency;

/**
 * 응답 객체 {@code Currency} (API 명세서 3절).
 *
 * @param minorUnit 소수 자리(표시·반올림)
 */
public record CurrencyResponse(String code, String name, int minorUnit, boolean isActive) {

    public static CurrencyResponse from(Currency currency) {
        return new CurrencyResponse(currency.code(), currency.name(), currency.minorUnit(), currency.active());
    }
}
