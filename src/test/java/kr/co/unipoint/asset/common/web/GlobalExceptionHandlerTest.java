package kr.co.unipoint.asset.common.web;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.csrf;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Positive;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import kr.co.unipoint.asset.common.api.ApiResponse;
import kr.co.unipoint.asset.common.api.BusinessException;
import kr.co.unipoint.asset.common.api.ErrorCode;
import kr.co.unipoint.asset.common.api.PageResponse;
import kr.co.unipoint.asset.common.internal.IdempotencyKeyStore;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.system.CapturedOutput;
import org.springframework.boot.test.system.OutputCaptureExtension;
import org.springframework.boot.webmvc.test.autoconfigure.WebMvcTest;
import org.springframework.context.annotation.Import;
import org.springframework.dao.OptimisticLockingFailureException;
import org.springframework.data.domain.PageImpl;
import org.springframework.data.domain.Pageable;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.security.authentication.BadCredentialsException;
import org.springframework.security.test.context.support.WithMockUser;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.assertj.MockMvcTester;
import org.springframework.test.web.servlet.assertj.MvcTestResult;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@WebMvcTest(GlobalExceptionHandlerTest.ProbeController.class) // 처리기 검사용 컨트롤러만 올린다
@Import(GlobalExceptionHandlerTest.ProbeController.class)
@ExtendWith(OutputCaptureExtension.class)
@WithMockUser // 보안 필터를 지나 처리기까지 오게 한다. 로그인 자체는 user 모듈 AuthApiTest에서 검사한다
class GlobalExceptionHandlerTest {

    @Autowired
    MockMvcTester mvc;

    @MockitoBean // 중복 요청 키 저장은 DB가 필요해 IdempotencyExecutorTest에서 검사한다
    IdempotencyKeyStore idempotencyKeys;

    @Test
    void 성공_응답은_OK_코드와_데이터를_담고_경고가_없으면_warnings를_뺀다() {
        MvcTestResult result = mvc.get().uri("/probe/ok").exchange();

        assertThat(result).hasStatus(HttpStatus.OK);
        assertThat(result).bodyJson().extractingPath("$.status").isEqualTo(200);
        assertThat(result).bodyJson().extractingPath("$.code").isEqualTo("OK");
        assertThat(result).bodyJson().extractingPath("$.message").isEqualTo("정상 처리했습니다");
        assertThat(result).bodyJson().extractingPath("$.data.itemCode").isEqualTo("01230850");
        assertThat(result).bodyJson().doesNotHavePath("$.warnings");
    }

    @Test
    void 경고가_있으면_warnings로_보낸다() {
        MvcTestResult result = mvc.get().uri("/probe/warning").exchange();

        assertThat(result).bodyJson().extractingPath("$.warnings[0].code").isEqualTo("COST_UNKNOWN");
    }

    @Test
    void 등록은_201() {
        MvcTestResult result = mvc.post().with(csrf()).uri("/probe/created").exchange();

        assertThat(result).hasStatus(HttpStatus.CREATED);
        assertThat(result).bodyJson().extractingPath("$.status").isEqualTo(201);
        assertThat(result).bodyJson().extractingPath("$.code").isEqualTo("OK");
    }

    @Test
    void 목록은_1부터_세는_페이지_정보를_담고_한_페이지는_최대_200건() {
        MvcTestResult result = mvc.get().uri("/probe/page?page=2&size=500").exchange();

        assertThat(result).bodyJson().extractingPath("$.data.page").isEqualTo(2);
        assertThat(result).bodyJson().extractingPath("$.data.size").isEqualTo(200);
        assertThat(result).bodyJson().extractingPath("$.data.totalCount").isEqualTo(132);
        assertThat(result).bodyJson().extractingPath("$.data.items").asArray().isEmpty();
    }

    @Test
    void 목록의_기본은_첫_페이지_50건() {
        MvcTestResult result = mvc.get().uri("/probe/page").exchange();

        assertThat(result).bodyJson().extractingPath("$.data.page").isEqualTo(1);
        assertThat(result).bodyJson().extractingPath("$.data.size").isEqualTo(50);
    }

    @Test
    void 업무_예외는_오류_코드의_HTTP_상태와_상세를_돌려준다() {
        MvcTestResult result = mvc.get().uri("/probe/business").exchange();

        assertThat(result).hasStatus(HttpStatus.NOT_FOUND);
        assertThat(result).bodyJson().extractingPath("$.status").isEqualTo(404);
        assertThat(result).bodyJson().extractingPath("$.code").isEqualTo("NOT_FOUND");
        assertThat(result).bodyJson().extractingPath("$.message").isEqualTo("제품을 찾을 수 없습니다");
        assertThat(result).bodyJson().extractingPath("$.data.invariant").isEqualTo("INV-99");
        assertThat(result).bodyJson().extractingPath("$.data.details.available").isEqualTo(2);
        assertThat(result).bodyJson().extractingPath("$.data.errors").asArray().isEmpty();
        assertThat(result)
                .bodyJson()
                .extractingPath("$.data.traceId")
                .asString()
                .matches("[0-9a-f]{32}");
    }

    @Test
    void 메시지를_주지_않으면_기본_메시지이고_없는_상세는_뺀다() {
        MvcTestResult result = mvc.get().uri("/probe/business-default").exchange();

        assertThat(result).hasStatus(HttpStatus.CONFLICT);
        assertThat(result).bodyJson().extractingPath("$.message").isEqualTo("같은 요청을 처리하고 있습니다");
        assertThat(result).bodyJson().doesNotHavePath("$.data.invariant");
        assertThat(result).bodyJson().doesNotHavePath("$.data.details");
    }

    @Test
    void 본문_검사_실패는_항목별_오류를_한_번에_돌려준다() {
        MvcTestResult result = mvc.post()
                .with(csrf())
                .uri("/probe/body")
                .contentType(MediaType.APPLICATION_JSON)
                .content("{\"name\":\" \",\"lines\":[{\"quantity\":1},{\"quantity\":0}]}")
                .exchange();

        assertThat(result).hasStatus(HttpStatus.BAD_REQUEST);
        assertThat(result).bodyJson().extractingPath("$.code").isEqualTo("VALIDATION_FAILED");
        assertThat(result).bodyJson().extractingPath("$.message").isEqualTo("입력 내용을 확인해 주세요");
        assertThat(result)
                .bodyJson()
                .extractingPath("$.data.errors[*].field")
                .asArray()
                .containsExactlyInAnyOrder("name", "lines[1].quantity");
        assertThat(result)
                .bodyJson()
                .extractingPath("$.data.errors[*].code")
                .asArray()
                .containsExactlyInAnyOrder("NOT_BLANK", "POSITIVE");
    }

    @Test
    void 읽을_수_없는_본문은_입력_오류() {
        MvcTestResult result = mvc.post()
                .with(csrf())
                .uri("/probe/body")
                .contentType(MediaType.APPLICATION_JSON)
                .content("{\"name\":")
                .exchange();

        assertThat(result).hasStatus(HttpStatus.BAD_REQUEST);
        assertThat(result).bodyJson().extractingPath("$.code").isEqualTo("VALIDATION_FAILED");
    }

    @Test
    void UUID가_아닌_id는_입력_오류() {
        MvcTestResult result = mvc.get().uri("/probe/item/15").exchange();

        assertThat(result).hasStatus(HttpStatus.BAD_REQUEST);
        assertThat(result).bodyJson().extractingPath("$.code").isEqualTo("VALIDATION_FAILED");
        assertThat(result).bodyJson().extractingPath("$.data.errors[0].field").isEqualTo("id");
        assertThat(result).bodyJson().extractingPath("$.data.errors[0].code").isEqualTo("TYPE_MISMATCH");
    }

    @Test
    void 중복_요청_키가_없으면_입력_오류() {
        MvcTestResult result = mvc.post().with(csrf()).uri("/probe/action").exchange();

        assertThat(result).hasStatus(HttpStatus.BAD_REQUEST);
        assertThat(result).bodyJson().extractingPath("$.code").isEqualTo("VALIDATION_FAILED");
        assertThat(result).bodyJson().extractingPath("$.data.errors[0].field").isEqualTo("Idempotency-Key");
        assertThat(result).bodyJson().extractingPath("$.data.errors[0].code").isEqualTo("REQUIRED");
    }

    @Test
    void 없는_경로는_404() {
        MvcTestResult result = mvc.get().uri("/probe/nothing-here").exchange();

        assertThat(result).hasStatus(HttpStatus.NOT_FOUND);
        assertThat(result).bodyJson().extractingPath("$.code").isEqualTo("NOT_FOUND");
    }

    @Test
    void 지원하지_않는_메서드는_405와_허용_메서드() {
        MvcTestResult result = mvc.delete().with(csrf()).uri("/probe/ok").exchange();

        assertThat(result).hasStatus(HttpStatus.METHOD_NOT_ALLOWED);
        assertThat(result).hasHeader("Allow", "GET");
        assertThat(result).bodyJson().extractingPath("$.status").isEqualTo(405);
        assertThat(result).bodyJson().extractingPath("$.code").isEqualTo("METHOD_NOT_ALLOWED");
    }

    @Test
    void 지원하지_않는_본문_형식은_415() {
        MvcTestResult result = mvc.post()
                .with(csrf())
                .uri("/probe/body")
                .contentType(MediaType.TEXT_PLAIN)
                .content("name")
                .exchange();

        assertThat(result).hasStatus(HttpStatus.UNSUPPORTED_MEDIA_TYPE);
        assertThat(result).bodyJson().extractingPath("$.status").isEqualTo(415);
        assertThat(result).bodyJson().extractingPath("$.code").isEqualTo("UNSUPPORTED_MEDIA_TYPE");
    }

    @Test
    void JSON으로_줄_수_없는_Accept는_본문_없이_406() {
        MvcTestResult result =
                mvc.get().uri("/probe/ok").accept(MediaType.APPLICATION_XML).exchange();

        assertThat(result).hasStatus(HttpStatus.NOT_ACCEPTABLE);
        assertThat(result.getResponse().getContentLength()).isZero();
    }

    @Test
    void 브라우저_언어가_영어여도_검사_메시지는_한국어() {
        MvcTestResult result = mvc.post()
                .with(csrf())
                .uri("/probe/body")
                .header("Accept-Language", "en-US")
                .contentType(MediaType.APPLICATION_JSON)
                .content("{\"name\":\" \",\"lines\":[]}")
                .exchange();

        assertThat(result)
                .bodyJson()
                .extractingPath("$.data.errors[0].message")
                .asString()
                .matches(".*[가-힣].*");
    }

    @Test
    void 낙관적_잠금_충돌은_409_VERSION_CONFLICT() {
        MvcTestResult result = mvc.get().uri("/probe/version-conflict").exchange();

        assertThat(result).hasStatus(HttpStatus.CONFLICT);
        assertThat(result).bodyJson().extractingPath("$.code").isEqualTo("VERSION_CONFLICT");
    }

    @Test
    void 처리_중에_난_권한_오류는_403_FORBIDDEN_인증_오류는_401_UNAUTHENTICATED() {
        MvcTestResult denied = mvc.get().uri("/probe/access-denied").exchange();
        MvcTestResult unauthenticated = mvc.get().uri("/probe/unauthenticated").exchange();

        assertThat(denied).hasStatus(HttpStatus.FORBIDDEN);
        assertThat(denied).bodyJson().extractingPath("$.code").isEqualTo("FORBIDDEN");
        assertThat(unauthenticated).hasStatus(HttpStatus.UNAUTHORIZED);
        assertThat(unauthenticated).bodyJson().extractingPath("$.code").isEqualTo("UNAUTHENTICATED");
    }

    @Test
    void 예상하지_못한_오류는_500이고_상세는_로그에만_traceId와_함께_남긴다(CapturedOutput output) throws Exception {
        MvcTestResult result = mvc.get().uri("/probe/unexpected").exchange();
        String body = result.getResponse().getContentAsString();
        String traceId = body.replaceAll(".*\"traceId\":\"([0-9a-f]+)\".*", "$1");

        assertThat(result).hasStatus(HttpStatus.INTERNAL_SERVER_ERROR);
        assertThat(result).bodyJson().extractingPath("$.code").isEqualTo("INTERNAL_ERROR");
        assertThat(result).bodyJson().extractingPath("$.message").isEqualTo("서버 오류가 발생했습니다");
        assertThat(body).doesNotContain("db password leaked");
        assertThat(traceId).matches("[0-9a-f]{32}");
        assertThat(output).contains("[" + traceId + "]").contains("db password leaked");
    }

    @Test
    void 검사_이름은_대문자_스네이크로_바꾼다() {
        assertThat(GlobalExceptionHandler.toCode("NotNull")).isEqualTo("NOT_NULL");
        assertThat(GlobalExceptionHandler.toCode("typeMismatch")).isEqualTo("TYPE_MISMATCH");
        assertThat(GlobalExceptionHandler.toCode(null)).isEqualTo("INVALID");
    }

    record ProbeLine(@Positive int quantity) {}

    record ProbeRequest(@NotBlank String name, @Valid List<ProbeLine> lines) {}

    @RestController
    @RequestMapping("/probe")
    static class ProbeController {

        @GetMapping("/ok")
        ApiResponse<Map<String, String>> ok() {
            return ApiResponse.ok(Map.of("itemCode", "01230850"));
        }

        @GetMapping("/warning")
        ApiResponse<Map<String, String>> warning() {
            return ApiResponse.ok(Map.of(), List.of(new ApiResponse.Warning("COST_UNKNOWN", "원가 미확인")));
        }

        @PostMapping("/created")
        ResponseEntity<ApiResponse<Map<String, String>>> created() {
            return ResponseEntity.status(HttpStatus.CREATED).body(ApiResponse.created(Map.of()));
        }

        @GetMapping("/page")
        ApiResponse<PageResponse<String>> page(Pageable pageable) {
            return ApiResponse.ok(PageResponse.from(new PageImpl<>(List.of(), pageable, 132)));
        }

        @GetMapping("/business")
        void business() {
            throw new BusinessException(ErrorCode.NOT_FOUND, "제품을 찾을 수 없습니다", "INV-99", Map.of("available", 2));
        }

        @GetMapping("/business-default")
        void businessDefault() {
            throw new BusinessException(ErrorCode.REQUEST_IN_PROGRESS);
        }

        @PostMapping("/body")
        void body(@Valid @RequestBody ProbeRequest request) {}

        @GetMapping("/item/{id}")
        void item(@PathVariable UUID id) {}

        @PostMapping("/action")
        void action(@RequestHeader("Idempotency-Key") UUID key) {}

        @GetMapping("/version-conflict")
        void versionConflict() {
            throw new OptimisticLockingFailureException("stale");
        }

        @GetMapping("/access-denied")
        void accessDenied() {
            throw new AccessDeniedException("no role");
        }

        @GetMapping("/unauthenticated")
        void unauthenticated() {
            throw new BadCredentialsException("bad");
        }

        @GetMapping("/unexpected")
        void unexpected() {
            throw new IllegalStateException("db password leaked");
        }
    }
}
