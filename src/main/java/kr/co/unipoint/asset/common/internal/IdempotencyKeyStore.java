package kr.co.unipoint.asset.common.internal;

import java.util.Optional;
import java.util.UUID;
import org.springframework.http.ResponseEntity;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Component;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.TransactionDefinition;
import org.springframework.transaction.support.TransactionTemplate;
import org.springframework.web.context.request.RequestAttributes;
import org.springframework.web.context.request.RequestContextHolder;
import tools.jackson.databind.json.JsonMapper;

/**
 * {@code common.idempotency_keys} 읽기·쓰기 (docs/db/table-definition.md 5.13, docs/api/api-spec.md 1.5).
 *
 * <p>키를 처음 저장할 때와 오류 응답을 저장·키를 지울 때는 업무 트랜잭션과 따로 커밋한다. 처리 중인 키가 다른 요청에 보여야 하고, 업무가 되돌려져도 오류
 * 응답은 남아야 하기 때문이다.
 */
@Component
public class IdempotencyKeyStore {

    private static final String CLAIMED_KEY = IdempotencyKeyStore.class.getName() + ".claimedKey";

    private final JdbcClient jdbc;
    private final JsonMapper json;
    private final TransactionTemplate separateTx;

    IdempotencyKeyStore(JdbcClient jdbc, JsonMapper json, PlatformTransactionManager transactionManager) {
        this.jdbc = jdbc;
        this.json = json;
        this.separateTx = new TransactionTemplate(transactionManager);
        this.separateTx.setPropagationBehavior(TransactionDefinition.PROPAGATION_REQUIRES_NEW);
    }

    /** 키를 IN_PROGRESS로 저장한다. 이미 있으면 저장하지 않고 false. */
    public boolean claim(UUID key, UUID userId, String action, String requestHash) {
        Integer inserted = separateTx.execute(status -> jdbc.sql("""
                        INSERT INTO common.idempotency_keys (idempotency_key, user_id, action, request_hash)
                        VALUES (:key, :userId, :action, :requestHash)
                        ON CONFLICT (idempotency_key) DO NOTHING
                        """)
                .param("key", key.toString())
                .param("userId", userId)
                .param("action", action)
                .param("requestHash", requestHash)
                .update());
        boolean claimed = inserted != null && inserted == 1;
        if (claimed) {
            markClaimedInCurrentRequest(key);
        }
        return claimed;
    }

    public Optional<StoredKey> find(UUID key) {
        return jdbc.sql("""
                        SELECT user_id, action, request_hash, status, response_status, response_body::text AS response_body
                        FROM common.idempotency_keys
                        WHERE idempotency_key = :key
                        """)
                .param("key", key.toString())
                .query((rs, rowNum) -> new StoredKey(
                        rs.getObject("user_id", UUID.class),
                        rs.getString("action"),
                        rs.getString("request_hash"),
                        rs.getString("status"),
                        (Integer) rs.getObject("response_status"),
                        rs.getString("response_body")))
                .optional();
    }

    /** 성공 응답을 저장하고 DONE으로 바꾼다. 업무 처리와 같은 트랜잭션에서 부른다. */
    public void complete(UUID key, ResponseEntity<?> response) {
        jdbc.sql("""
                        UPDATE common.idempotency_keys
                        SET status = 'DONE', response_status = :status, response_body = CAST(:body AS jsonb), completed_at = now()
                        WHERE idempotency_key = :key
                        """)
                .param("key", key.toString())
                .param("status", response.getStatusCode().value())
                .param("body", json.writeValueAsString(response.getBody()))
                .update();
    }

    /**
     * 이번 요청에서 저장한 키가 있으면 오류 응답에 맞춰 정리한다. 업무 오류(4xx)면 응답을 저장하고, 서버 오류(5xx)면 키를 지워 같은 키로 다시 보낼 수 있게
     * 한다. 공통 예외 처리기가 부른다.
     */
    public void recordFailure(ResponseEntity<?> response) {
        RequestAttributes attributes = RequestContextHolder.getRequestAttributes();
        if (attributes == null) {
            return;
        }
        UUID key = (UUID) attributes.getAttribute(CLAIMED_KEY, RequestAttributes.SCOPE_REQUEST);
        if (key == null) {
            return;
        }
        attributes.removeAttribute(CLAIMED_KEY, RequestAttributes.SCOPE_REQUEST);
        if (response.getStatusCode().is4xxClientError()) {
            separateTx.executeWithoutResult(status -> complete(key, response));
        } else {
            separateTx.executeWithoutResult(
                    status -> jdbc.sql("DELETE FROM common.idempotency_keys WHERE idempotency_key = :key")
                            .param("key", key.toString())
                            .update());
        }
    }

    /** 7일이 지난 키를 지운다 (docs/api/api-spec.md 1.5). */
    public int deleteExpired() {
        return jdbc.sql("DELETE FROM common.idempotency_keys WHERE created_at < now() - interval '7 days'")
                .update();
    }

    private static void markClaimedInCurrentRequest(UUID key) {
        RequestAttributes attributes = RequestContextHolder.getRequestAttributes();
        if (attributes != null) {
            attributes.setAttribute(CLAIMED_KEY, key, RequestAttributes.SCOPE_REQUEST);
        }
    }

    /** 저장된 키 한 줄. {@code status}는 IN_PROGRESS 또는 DONE. */
    public record StoredKey(
            UUID userId,
            String action,
            String requestHash,
            String status,
            Integer responseStatus,
            String responseBody) {

        public boolean done() {
            return "DONE".equals(status);
        }
    }
}
