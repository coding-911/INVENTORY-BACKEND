package kr.co.unipoint.asset.user;

/**
 * 권한 13개 (docs/rules/permissions.md 1.2, 확정 사항 #106). DB {@code auth.permissions}와 같아야 한다(테스트로 확인).
 *
 * <p>API 권한은 {@code @PreAuthorize("hasAuthority('MASTER_MANAGE')")}처럼 이 이름으로 검사한다. {@code hasRole}은 쓰지 않는다: 역할은
 * 관리자가 만드는 데이터라 코드가 역할을 알면 안 된다.
 */
public enum Permission {
    PARTNER_MANAGE,
    PRODUCT_MANAGE,
    MASTER_MANAGE,
    DOCUMENT_MANAGE,
    STOCK_OPERATE,
    STOCK_ADJUST,
    APPROVE,
    CLOSING,
    RECORD_CORRECT,
    AUDIT_VIEW,
    USER_MANAGE,
    COST_VIEW,
    COST_EDIT
}
