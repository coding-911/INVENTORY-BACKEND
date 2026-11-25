package kr.co.unipoint.asset.user.internal;

import java.io.Serial;
import java.io.Serializable;
import java.time.Instant;
import java.util.UUID;
import org.springframework.security.core.AuthenticatedPrincipal;

/**
 * 세션에 저장하는 것은 이것뿐이다: 사용자 ID와 로그인 시각 (ADR-17, 2026-11-25).
 *
 * <p>세션 테이블에는 자바 직렬화로 저장된다. 여기 담은 클래스가 바뀌면 이미 저장된 세션을 읽지 못해 오류가 나므로, 바뀔 일이 많은 역할·금액 권한·이름은
 * 넣지 않고 요청마다 DB에서 읽는다({@link SessionCheckFilter}가 {@link LoginUser}로 만든다). 이 클래스는 고치지 않는다. 고쳐야 하면 배포 때
 * 세션 테이블을 비운다(모두 다시 로그인).
 *
 * <p>{@link #getName()}은 사용자 ID라서 세션 테이블의 {@code principal_name}에 사용자 ID가 들어간다.
 *
 * @param loginAt 로그인한 시각(DB 시각). {@code users.tokens_valid_after}보다 이르면 세션을 끊는다 (INV-80)
 */
public record SessionUser(UUID id, Instant loginAt) implements AuthenticatedPrincipal, Serializable {

    @Serial
    private static final long serialVersionUID = 1L;

    @Override
    public String getName() {
        return id.toString();
    }
}
