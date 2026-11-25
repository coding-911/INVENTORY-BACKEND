package kr.co.unipoint.asset.common.api;

import java.util.List;
import org.springframework.data.domain.Page;

/**
 * 목록 응답의 {@code data}. {@code page}는 1부터 센다 (docs/api/api-spec.md 1.7).
 */
public record PageResponse<T>(List<T> items, int page, int size, long totalCount) {

    public PageResponse {
        items = List.copyOf(items);
    }

    public static <T> PageResponse<T> from(Page<T> page) {
        return new PageResponse<>(page.getContent(), page.getNumber() + 1, page.getSize(), page.getTotalElements());
    }
}
