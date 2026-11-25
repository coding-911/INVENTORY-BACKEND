package kr.co.unipoint.asset.common.api;

import static org.assertj.core.api.Assertions.assertThat;

import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.concurrent.CompletableFuture;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicInteger;
import kr.co.unipoint.asset.common.internal.IdempotencyKeyStore;
import kr.co.unipoint.asset.support.TestcontainersConfiguration;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.context.annotation.Import;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.test.web.servlet.assertj.MockMvcTester;
import org.springframework.test.web.servlet.assertj.MvcTestResult;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RestController;

@SpringBootTest
@AutoConfigureMockMvc
@Import({TestcontainersConfiguration.class, IdempotencyExecutorTest.ProbeController.class})
class IdempotencyExecutorTest {

    static final AtomicInteger calls = new AtomicInteger();
    static volatile CountDownLatch started = new CountDownLatch(1);
    static volatile CountDownLatch release = new CountDownLatch(0);

    @Autowired
    MockMvcTester mvc;

    @Autowired
    JdbcClient jdbc;

    @Autowired
    IdempotencyKeyStore store;

    final UUID user = UUID.randomUUID();

    @BeforeEach
    void setUp() {
        calls.set(0);
        jdbc.sql("CREATE TABLE IF NOT EXISTS public.probe_writes (id uuid PRIMARY KEY)")
                .update();
        jdbc.sql("TRUNCATE public.probe_writes").update();
    }

    @Test
    void INV08_같은_키로_다시_보내면_처음_응답을_그대로_돌려주고_한_번만_처리한다() throws Exception {
        UUID key = UUID.randomUUID();

        MvcTestResult first = post("/probe/write/ok", key, user, "{\"quantity\":3}");
        MvcTestResult second = post("/probe/write/ok", key, user, "{\"quantity\":3}");

        assertThat(first).hasStatus(HttpStatus.CREATED);
        assertThat(second).hasStatus(HttpStatus.CREATED);
        assertThat(second.getResponse().getContentAsString())
                .isEqualTo(first.getResponse().getContentAsString()); // 필드 순서까지 같다
        assertThat(calls).hasValue(1);
        assertThat(writes()).isEqualTo(1);
        assertThat(row(key)).containsEntry("status", "DONE").containsEntry("response_status", 201);
    }

    @Test
    void INV08_요청_내용이_다르면_REQUEST_KEY_REUSED() {
        UUID key = UUID.randomUUID();
        post("/probe/write/ok", key, user, "{\"quantity\":3}");

        MvcTestResult result = post("/probe/write/ok", key, user, "{\"quantity\":4}");

        assertThat(result).hasStatus(HttpStatus.BAD_REQUEST);
        assertThat(result).bodyJson().extractingPath("$.code").isEqualTo("REQUEST_KEY_REUSED");
        assertThat(calls).hasValue(1);
    }

    @Test
    void INV08_요청자가_다르면_REQUEST_KEY_REUSED() {
        UUID key = UUID.randomUUID();
        post("/probe/write/ok", key, user, "{\"quantity\":3}");

        MvcTestResult result = post("/probe/write/ok", key, UUID.randomUUID(), "{\"quantity\":3}");

        assertThat(result).bodyJson().extractingPath("$.code").isEqualTo("REQUEST_KEY_REUSED");
    }

    @Test
    void INV08_동작이_다르면_REQUEST_KEY_REUSED() {
        UUID key = UUID.randomUUID();
        post("/probe/write/ok", key, user, "{\"quantity\":3}");

        MvcTestResult result = post("/probe/write/other", key, user, "{\"quantity\":3}");

        assertThat(result).bodyJson().extractingPath("$.code").isEqualTo("REQUEST_KEY_REUSED");
    }

    @Test
    void INV08_처리_중인_키는_409_REQUEST_IN_PROGRESS이고_한_번만_처리한다() throws Exception {
        UUID key = UUID.randomUUID();
        started = new CountDownLatch(1);
        release = new CountDownLatch(1);

        CompletableFuture<MvcTestResult> first =
                CompletableFuture.supplyAsync(() -> post("/probe/write/slow", key, user, "{\"quantity\":1}"));
        assertThat(started.await(10, TimeUnit.SECONDS)).isTrue();
        MvcTestResult second = post("/probe/write/slow", key, user, "{\"quantity\":1}");
        release.countDown();

        assertThat(second).hasStatus(HttpStatus.CONFLICT);
        assertThat(second).bodyJson().extractingPath("$.code").isEqualTo("REQUEST_IN_PROGRESS");
        assertThat(first.get(10, TimeUnit.SECONDS)).hasStatus(HttpStatus.CREATED);
        assertThat(calls).hasValue(1);
        assertThat(writes()).isEqualTo(1);
    }

    @Test
    void 업무_오류는_되돌리고_그_응답을_저장해_같은_키면_같은_오류를_준다() throws Exception {
        UUID key = UUID.randomUUID();

        MvcTestResult first = post("/probe/write/business-error", key, user, "{\"quantity\":3}");
        MvcTestResult second = post("/probe/write/business-error", key, user, "{\"quantity\":3}");

        assertThat(first).hasStatus(HttpStatus.BAD_REQUEST);
        assertThat(first).bodyJson().extractingPath("$.code").isEqualTo("VALIDATION_FAILED");
        assertThat(second.getResponse().getContentAsString())
                .isEqualTo(first.getResponse().getContentAsString()); // 필드 순서까지 같다
        assertThat(calls).hasValue(1);
        assertThat(writes()).isZero(); // 업무 처리는 되돌려졌다
        assertThat(row(key)).containsEntry("status", "DONE").containsEntry("response_status", 400);
    }

    @Test
    void 서버_오류면_키를_지워_같은_키로_다시_처리할_수_있다() {
        UUID key = UUID.randomUUID();

        MvcTestResult first = post("/probe/write/server-error", key, user, "{\"quantity\":3}");

        assertThat(first).hasStatus(HttpStatus.INTERNAL_SERVER_ERROR);
        assertThat(writes()).isZero();
        assertThat(store.find(key)).isEmpty();

        post("/probe/write/server-error", key, user, "{\"quantity\":3}");
        assertThat(calls).hasValue(2);
    }

    @Test
    void 키가_없으면_기록_없이_매번_처리한다() {
        post("/probe/write/ok", null, user, "{\"quantity\":3}");
        post("/probe/write/ok", null, user, "{\"quantity\":3}");

        assertThat(calls).hasValue(2);
    }

    @Test
    void 지난_7일이_넘은_키만_지운다() {
        UUID oldKey = UUID.randomUUID();
        UUID recentKey = UUID.randomUUID();
        insertKey(oldKey, "8 days");
        insertKey(recentKey, "6 days");

        store.deleteExpired();

        assertThat(store.find(oldKey)).isEmpty();
        assertThat(store.find(recentKey)).isPresent();
    }

    private MvcTestResult post(String uri, UUID key, UUID userId, String body) {
        var request = mvc.post()
                .uri(uri)
                .header("X-User", userId.toString())
                .contentType(MediaType.APPLICATION_JSON)
                .content(body);
        if (key != null) {
            request = request.header("Idempotency-Key", key.toString());
        }
        return request.exchange();
    }

    private int writes() {
        return jdbc.sql("SELECT count(*) FROM public.probe_writes")
                .query(Integer.class)
                .single();
    }

    private Map<String, Object> row(UUID key) {
        return jdbc.sql("SELECT status, response_status FROM common.idempotency_keys WHERE idempotency_key = :key")
                .param("key", key.toString())
                .query()
                .singleRow();
    }

    private void insertKey(UUID key, String age) {
        jdbc.sql("""
                        INSERT INTO common.idempotency_keys (idempotency_key, user_id, action, request_hash, created_at)
                        VALUES (:key, :user, 'probe', 'h', now() - CAST(:age AS interval))
                        """)
                .param("key", key.toString())
                .param("user", user)
                .param("age", age)
                .update();
    }

    record ProbeRequest(int quantity) {}

    @RestController
    static class ProbeController {

        private final IdempotencyExecutor idempotency;
        private final JdbcClient jdbc;

        ProbeController(IdempotencyExecutor idempotency, JdbcClient jdbc) {
            this.idempotency = idempotency;
            this.jdbc = jdbc;
        }

        @PostMapping("/probe/write/{mode}")
        ResponseEntity<?> write(
                @PathVariable String mode,
                @RequestHeader(name = "Idempotency-Key", required = false) UUID key,
                @RequestHeader("X-User") UUID user,
                @RequestBody ProbeRequest request) {
            String action = mode.equals("other") ? "probe.other" : "probe.write";
            return idempotency.execute(key, user, action, request, () -> {
                calls.incrementAndGet();
                UUID id = UUID.randomUUID();
                jdbc.sql("INSERT INTO public.probe_writes (id) VALUES (:id)")
                        .param("id", id)
                        .update();
                switch (mode) {
                    case "slow" -> {
                        started.countDown();
                        await(release);
                    }
                    case "business-error" -> throw new BusinessException(ErrorCode.VALIDATION_FAILED);
                    case "server-error" -> throw new IllegalStateException("probe");
                    default -> {}
                }
                return ResponseEntity.status(HttpStatus.CREATED)
                        .body(ApiResponse.created(Map.of("id", id, "quantity", request.quantity(), "list", List.of())));
            });
        }

        private static void await(CountDownLatch latch) {
            try {
                latch.await(10, TimeUnit.SECONDS);
            } catch (InterruptedException e) {
                Thread.currentThread().interrupt();
            }
        }
    }
}
