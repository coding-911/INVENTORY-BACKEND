package kr.co.unipoint.asset.common.internal;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

/** 7일이 지난 중복 요청 키를 매일 새벽에 지운다 (docs/api/api-spec.md 1.5, docs/dev/tech-stack.md 일정 작업). */
@Component
class IdempotencyKeyCleanup {

    private static final Logger log = LoggerFactory.getLogger(IdempotencyKeyCleanup.class);

    private final IdempotencyKeyStore store;

    IdempotencyKeyCleanup(IdempotencyKeyStore store) {
        this.store = store;
    }

    @Scheduled(cron = "0 30 3 * * *", zone = "Asia/Seoul")
    void deleteExpired() {
        int deleted = store.deleteExpired();
        log.info("지난 중복 요청 키 {}건을 지웠습니다", deleted);
    }
}
