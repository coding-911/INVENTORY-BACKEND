package kr.co.unipoint.asset.cost.internal;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.PostLoad;
import jakarta.persistence.PostPersist;
import jakarta.persistence.Table;
import jakarta.persistence.Transient;
import kr.co.unipoint.asset.common.api.BusinessException;
import kr.co.unipoint.asset.common.api.ErrorCode;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;
import org.springframework.data.domain.Persistable;

/**
 * 통화 ({@code cost.currencies}, 테이블 정의서 cost). 금액 기록이 코드로 가리키므로 삭제하지 않고 끈다. 코드·소수 자리는 바꾸지 않는다 (API 명세서
 * 1.9, API 목록 "통화 수정").
 *
 * <p>감사 컬럼·{@code version}이 없는 코드 표다({@code MASTER_MANAGE}만 드물게 바꿈, 1.9). id가 통화 코드라 새로 만든 것인지 스스로 알려 준다({@link
 * Persistable}). 그러지 않으면 저장할 때 같은 코드의 기존 행을 덮어쓸 수 있다.
 */
@Entity
@Table(schema = "cost", name = "currencies")
public class Currency implements Persistable<String> {

    public static final String KRW = "KRW";

    @Id
    @JdbcTypeCode(SqlTypes.CHAR)
    @Column(length = 3)
    private String code;

    private String name;

    private short minorUnit;

    @Column(name = "is_active")
    private boolean active;

    @Transient
    private boolean isNew;

    protected Currency() {}

    private Currency(String code, String name, short minorUnit, boolean active) {
        this.code = code;
        this.name = name;
        this.minorUnit = minorUnit;
        this.active = active;
        this.isNew = true;
    }

    static Currency create(String code, String name, short minorUnit, boolean active) {
        return new Currency(code, name, minorUnit, active);
    }

    void rename(String name) {
        this.name = name;
    }

    /** 원화는 모든 금액의 기본 통화라 끌 수 없다. */
    void changeActive(boolean active) {
        if (!active && KRW.equals(code)) {
            throw new BusinessException(ErrorCode.CURRENCY_KRW_REQUIRED);
        }
        this.active = active;
    }

    @PostLoad
    @PostPersist
    void markNotNew() {
        this.isNew = false;
    }

    @Override
    public String getId() {
        return code;
    }

    @Override
    public boolean isNew() {
        return isNew;
    }

    public String code() {
        return code;
    }

    public String name() {
        return name;
    }

    public short minorUnit() {
        return minorUnit;
    }

    public boolean active() {
        return active;
    }
}
