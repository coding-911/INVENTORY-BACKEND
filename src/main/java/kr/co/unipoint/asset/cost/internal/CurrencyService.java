package kr.co.unipoint.asset.cost.internal;

import java.util.List;
import kr.co.unipoint.asset.common.api.BusinessException;
import kr.co.unipoint.asset.common.api.ErrorCode;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/** 통화 목록·추가·수정 (API 목록 "통화 목록", "통화 추가", "통화 수정"). 권한은 컨트롤러가 본다. */
@Service
public class CurrencyService {

    private final CurrencyRepository currencies;

    CurrencyService(CurrencyRepository currencies) {
        this.currencies = currencies;
    }

    /** 페이지 없이 코드 순. {@code active}가 없으면 켜진 것과 꺼진 것 모두. 통화는 몇 개뿐인 코드 표다. */
    @Transactional(readOnly = true)
    public List<Currency> list(Boolean active) {
        return active == null ? currencies.findAllByOrderByCode() : currencies.findByActiveOrderByCode(active);
    }

    /**
     * 같은 코드가 있으면 400 {@code CURRENCY_CODE_DUPLICATE}. 동시에 같은 코드를 넣으면 늦은 쪽이 기본 키 위반으로 막히고 같은 오류가 된다(이
     * 테이블의 제약은 기본 키와 NOT NULL뿐이고 NOT NULL은 요청 검사가 먼저 막는다).
     */
    @Transactional
    public Currency add(String code, String name, short minorUnit, boolean active) {
        if (currencies.existsById(code)) {
            throw new BusinessException(ErrorCode.CURRENCY_CODE_DUPLICATE);
        }
        try {
            return currencies.saveAndFlush(Currency.create(code, name, minorUnit, active));
        } catch (DataIntegrityViolationException e) {
            throw new BusinessException(ErrorCode.CURRENCY_CODE_DUPLICATE);
        }
    }

    /** 보낸 항목만 바꾼다. 없는 코드면 404, 원화를 끄면 400 {@code CURRENCY_KRW_REQUIRED}. */
    @Transactional
    public Currency update(String code, String name, Boolean active) {
        Currency currency = currencies.findById(code).orElseThrow(() -> new BusinessException(ErrorCode.NOT_FOUND));
        if (name != null) {
            currency.rename(name);
        }
        if (active != null) {
            currency.changeActive(active);
        }
        return currency;
    }
}
