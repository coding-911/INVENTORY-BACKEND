package kr.co.unipoint.asset.common.api;

import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.util.HexFormat;
import java.util.UUID;
import java.util.function.Supplier;
import kr.co.unipoint.asset.common.internal.IdempotencyKeyStore;
import kr.co.unipoint.asset.common.internal.IdempotencyKeyStore.StoredKey;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.stereotype.Component;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.support.TransactionTemplate;
import tools.jackson.databind.json.JsonMapper;

/**
 * 같은 요청이 두 번 와도 한 번만 반영한다 (INV-08, docs/api/api-spec.md 1.5, docs/db/table-definition.md 5.13).
 *
 * <p>컨트롤러가 {@code Idempotency-Key} 헤더와 함께 부른다. 업무 동작은 헤더를 필수({@code @RequestHeader("Idempotency-Key") UUID})로,
 * 일반 등록·수정은 선택({@code required = false})으로 받는다.
 *
 * <pre>{@code
 * return idempotency.execute(key, userId, "delivery.receipt", request,
 *         () -> ResponseEntity.status(HttpStatus.CREATED).body(ApiResponse.created(service.receive(request))));
 * }</pre>
 *
 * <ul>
 *   <li>처음 온 키: 키를 따로 저장(IN_PROGRESS)한 뒤 업무를 처리하고, 같은 트랜잭션에서 응답을 저장한다(DONE).
 *   <li>업무 오류(4xx)로 끝나면 그 응답을 저장하고, 서버 오류(5xx)면 키를 지운다. 공통 예외 처리기가 한다.
 *   <li>같은 키가 다시 오면: 요청자·동작·요청 내용이 하나라도 다르면 400 {@code REQUEST_KEY_REUSED}, 처리 중이면 409
 *       {@code REQUEST_IN_PROGRESS}, 끝났으면 처음 응답을 그대로 돌려준다.
 * </ul>
 */
@Component
public class IdempotencyExecutor {

    private final IdempotencyKeyStore store;
    private final JsonMapper json;
    private final TransactionTemplate tx;

    IdempotencyExecutor(IdempotencyKeyStore store, JsonMapper json, PlatformTransactionManager transactionManager) {
        this.store = store;
        this.json = json;
        this.tx = new TransactionTemplate(transactionManager);
    }

    /**
     * @param key {@code Idempotency-Key} 헤더. null이면(선택인 API에서 보내지 않음) 기록 없이 처리한다
     * @param userId 요청자
     * @param action API 동작 이름. 예: {@code delivery.receipt}
     * @param request 요청 내용(본문, 필요하면 경로의 id도 담은 객체). 해시를 비교해 다른 요청에 같은 키를 쓰면 막는다
     * @param work 업무 처리와 응답 만들기
     */
    public ResponseEntity<?> execute(
            UUID key, UUID userId, String action, Object request, Supplier<? extends ResponseEntity<?>> work) {
        if (key == null) {
            return work.get();
        }
        String requestHash = hash(request);
        if (!store.claim(key, userId, action, requestHash)) {
            return replay(key, userId, action, requestHash);
        }
        return tx.execute(status -> {
            ResponseEntity<?> response = work.get();
            store.complete(key, response);
            return response;
        });
    }

    private ResponseEntity<?> replay(UUID key, UUID userId, String action, String requestHash) {
        // 찾지 못하면 그사이 서버 오류로 키가 지워진 것이다. 처리 중으로 알리고 다시 보내게 한다
        StoredKey stored = store.find(key).orElseThrow(() -> new BusinessException(ErrorCode.REQUEST_IN_PROGRESS));
        if (!stored.userId().equals(userId)
                || !stored.action().equals(action)
                || !stored.requestHash().equals(requestHash)) {
            throw new BusinessException(ErrorCode.REQUEST_KEY_REUSED);
        }
        if (!stored.done()) {
            throw new BusinessException(ErrorCode.REQUEST_IN_PROGRESS);
        }
        return ResponseEntity.status(stored.responseStatus())
                .contentType(MediaType.APPLICATION_JSON)
                .body(json.readTree(stored.responseBody()));
    }

    private String hash(Object request) {
        try {
            byte[] digest = MessageDigest.getInstance("SHA-256").digest(json.writeValueAsBytes(request));
            return HexFormat.of().formatHex(digest);
        } catch (NoSuchAlgorithmException e) {
            throw new IllegalStateException("SHA-256을 쓸 수 없습니다", e);
        }
    }
}
