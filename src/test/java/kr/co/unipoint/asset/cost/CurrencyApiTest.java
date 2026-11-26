package kr.co.unipoint.asset.cost;

import static kr.co.unipoint.asset.support.TestLogins.xsrf;
import static org.assertj.core.api.Assertions.assertThat;

import com.jayway.jsonpath.JsonPath;
import jakarta.servlet.http.Cookie;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.concurrent.Callable;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
import kr.co.unipoint.asset.support.TestLogins;
import kr.co.unipoint.asset.support.TestcontainersConfiguration;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.context.annotation.Import;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.test.web.servlet.assertj.MockMvcTester;
import org.springframework.test.web.servlet.assertj.MvcTestResult;

/** 통화 목록·추가·수정 (API 목록 "통화 목록", "통화 추가", "통화 수정", 권한 매트릭스 3.1·3.3, API 명세서 1.9). */
@SpringBootTest
@AutoConfigureMockMvc
@Import(TestcontainersConfiguration.class)
class CurrencyApiTest {

    @Autowired
    MockMvcTester mvc;

    @Autowired
    JdbcClient jdbc;

    @Autowired
    PasswordEncoder passwordEncoder;

    TestLogins logins;

    @BeforeEach
    void setUp() {
        logins = new TestLogins(mvc, jdbc, passwordEncoder);
    }

    @Test
    void 목록은_조회자도_보고_코드_순이며_처음에는_원화_켜짐_달러_꺼짐() throws Exception {
        Cookie viewer = logins.loginAs("VIEWER");

        MvcTestResult result =
                mvc.get().uri("/api/v1/cost/currency").cookie(viewer).exchange();

        assertThat(result).hasStatus(HttpStatus.OK);
        List<String> codes = codes(result);
        assertThat(codes).contains("KRW", "USD");
        assertThat(codes).isSorted();
        assertThat(result)
                .bodyJson()
                .extractingPath("$.data[?(@.code == 'KRW')]")
                .asArray()
                .singleElement()
                .isEqualTo(Map.of("code", "KRW", "name", "대한민국 원", "minorUnit", 0, "isActive", true));
        assertThat(result)
                .bodyJson()
                .extractingPath("$.data[?(@.code == 'USD')].isActive")
                .asArray()
                .containsExactly(false);
    }

    @Test
    void 목록은_isActive로_거른다() throws Exception {
        Cookie viewer = logins.loginAs("VIEWER");

        MvcTestResult active = mvc.get()
                .uri("/api/v1/cost/currency")
                .param("isActive", "true")
                .cookie(viewer)
                .exchange();
        MvcTestResult inactive = mvc.get()
                .uri("/api/v1/cost/currency")
                .param("isActive", "false")
                .cookie(viewer)
                .exchange();

        assertThat(codes(active)).contains("KRW").doesNotContain("USD");
        assertThat(codes(inactive)).contains("USD").doesNotContain("KRW");
    }

    @Test
    void 로그인하지_않으면_목록도_401() {
        MvcTestResult result = mvc.get().uri("/api/v1/cost/currency").exchange();

        assertThat(result).hasStatus(HttpStatus.UNAUTHORIZED);
    }

    @Test
    void 관리자가_추가하면_201이고_isActive가_없으면_꺼진_채로_들어간다() {
        Cookie admin = logins.loginAs("ADMIN");

        MvcTestResult result = add(admin, "{\"code\":\"EUR\",\"name\":\"유로\",\"minorUnit\":2}");

        assertThat(result).hasStatus(HttpStatus.CREATED);
        assertThat(result).bodyJson().extractingPath("$.status").isEqualTo(201);
        assertThat(result)
                .bodyJson()
                .extractingPath("$.data")
                .isEqualTo(Map.of("code", "EUR", "name", "유로", "minorUnit", 2, "isActive", false));
        assertThat(jdbc.sql("SELECT is_active FROM cost.currencies WHERE code = 'EUR'")
                        .query(Boolean.class)
                        .single())
                .isFalse();
    }

    @Test
    void 이미_있는_코드면_400_CURRENCY_CODE_DUPLICATE이고_기존_행은_그대로() {
        Cookie admin = logins.loginAs("ADMIN");

        MvcTestResult result = add(admin, "{\"code\":\"KRW\",\"name\":\"덮어쓰기\",\"minorUnit\":2,\"isActive\":false}");

        assertThat(result).hasStatus(HttpStatus.BAD_REQUEST);
        assertThat(result).bodyJson().extractingPath("$.code").isEqualTo("CURRENCY_CODE_DUPLICATE");
        assertThat(result).bodyJson().extractingPath("$.message").isEqualTo("이미 있는 통화입니다");
        Map<String, Object> krw = jdbc.sql("SELECT name, minor_unit, is_active FROM cost.currencies WHERE code = 'KRW'")
                .query()
                .singleRow();
        assertThat(krw).containsEntry("name", "대한민국 원").containsEntry("is_active", true);
        assertThat(((Number) krw.get("minor_unit")).intValue()).isZero();
    }

    @Test
    void 같은_코드를_동시에_추가하면_하나만_201이고_나머지는_CURRENCY_CODE_DUPLICATE() throws Exception {
        Cookie admin = logins.loginAs("ADMIN");
        int threads = 4;
        CountDownLatch start = new CountDownLatch(1);
        Callable<Integer> task = () -> {
            start.await();
            return add(admin, "{\"code\":\"CHF\",\"name\":\"스위스 프랑\",\"minorUnit\":2}")
                    .getResponse()
                    .getStatus();
        };
        List<Integer> statuses;
        try (ExecutorService pool = Executors.newFixedThreadPool(threads)) {
            List<Future<Integer>> futures = new ArrayList<>();
            for (int i = 0; i < threads; i++) {
                futures.add(pool.submit(task));
            }
            start.countDown();
            statuses = new ArrayList<>();
            for (Future<Integer> future : futures) {
                statuses.add(future.get());
            }
        }

        assertThat(statuses).filteredOn(status -> status == 201).hasSize(1);
        assertThat(statuses).filteredOn(status -> status == 400).hasSize(threads - 1);
        assertThat(jdbc.sql("SELECT count(*) FROM cost.currencies WHERE code = 'CHF'")
                        .query(Integer.class)
                        .single())
                .isEqualTo(1);
    }

    @Test
    void 추가_입력이_틀리면_400_VALIDATION_FAILED() {
        Cookie admin = logins.loginAs("ADMIN");

        MvcTestResult lowerCase = add(admin, "{\"code\":\"eur\",\"name\":\"유로\",\"minorUnit\":2}");
        MvcTestResult missing = add(admin, "{}");
        MvcTestResult tooManyDigits = add(admin, "{\"code\":\"XAA\",\"name\":\"가\",\"minorUnit\":5}");
        MvcTestResult tooLongName =
                add(admin, "{\"code\":\"XAB\",\"name\":\"" + "가".repeat(51) + "\",\"minorUnit\":2}");

        assertThat(lowerCase).hasStatus(HttpStatus.BAD_REQUEST);
        assertThat(lowerCase)
                .bodyJson()
                .extractingPath("$.data.errors[0].field")
                .isEqualTo("code");
        assertThat(lowerCase)
                .bodyJson()
                .extractingPath("$.data.errors[0].message")
                .isEqualTo("영문 대문자 3자로 넣어 주세요");
        assertThat(missing).bodyJson().extractingPath("$.data.errors.length()").isEqualTo(3);
        assertThat(tooManyDigits)
                .bodyJson()
                .extractingPath("$.data.errors[0].field")
                .isEqualTo("minorUnit");
        assertThat(tooLongName)
                .bodyJson()
                .extractingPath("$.data.errors[0].field")
                .isEqualTo("name");
        assertThat(jdbc.sql("SELECT count(*) FROM cost.currencies WHERE code IN ('XAA', 'XAB')")
                        .query(Integer.class)
                        .single())
                .isZero();
    }

    @Test
    void 입력자와_조회자는_추가_수정이_403_FORBIDDEN() {
        for (String role : List.of("OPERATOR", "VIEWER")) {
            Cookie session = logins.loginAs(role, "COST_VIEW");

            MvcTestResult added = add(session, "{\"code\":\"GBP\",\"name\":\"영국 파운드\",\"minorUnit\":2}");
            MvcTestResult updated = update(session, "USD", "{\"isActive\":true}");

            assertThat(added).hasStatus(HttpStatus.FORBIDDEN);
            assertThat(added).bodyJson().extractingPath("$.code").isEqualTo("FORBIDDEN");
            assertThat(updated).hasStatus(HttpStatus.FORBIDDEN);
        }
        assertThat(jdbc.sql("SELECT count(*) FROM cost.currencies WHERE code = 'GBP'")
                        .query(Integer.class)
                        .single())
                .isZero();
        assertThat(jdbc.sql("SELECT is_active FROM cost.currencies WHERE code = 'USD'")
                        .query(Boolean.class)
                        .single())
                .isFalse();
    }

    @Test
    void 금액_수정_권한이_있는_입력자도_추가는_403() {
        Cookie operator = logins.loginAs("OPERATOR", "COST_VIEW", "COST_EDIT");

        MvcTestResult result = add(operator, "{\"code\":\"GBP\",\"name\":\"영국 파운드\",\"minorUnit\":2}");

        assertThat(result).hasStatus(HttpStatus.FORBIDDEN);
    }

    @Test
    void 관리자가_보낸_항목만_바꾼다() {
        Cookie admin = logins.loginAs("ADMIN");
        add(admin, "{\"code\":\"JPY\",\"name\":\"일본 엔\",\"minorUnit\":0}");

        MvcTestResult renamed = update(admin, "JPY", "{\"name\":\"일본 엔화\"}");
        MvcTestResult activated = update(admin, "JPY", "{\"isActive\":true}");

        assertThat(renamed).hasStatus(HttpStatus.OK);
        assertThat(renamed)
                .bodyJson()
                .extractingPath("$.data")
                .isEqualTo(Map.of("code", "JPY", "name", "일본 엔화", "minorUnit", 0, "isActive", false));
        assertThat(activated)
                .bodyJson()
                .extractingPath("$.data")
                .isEqualTo(Map.of("code", "JPY", "name", "일본 엔화", "minorUnit", 0, "isActive", true));
    }

    @Test
    void 수정은_코드_소수_자리를_바꾸지_않는다() {
        Cookie admin = logins.loginAs("ADMIN");
        add(admin, "{\"code\":\"CNY\",\"name\":\"중국 위안\",\"minorUnit\":2}");

        MvcTestResult result = update(admin, "CNY", "{\"code\":\"CNH\",\"minorUnit\":0,\"name\":\"위안\"}");

        assertThat(result).hasStatus(HttpStatus.OK);
        assertThat(result)
                .bodyJson()
                .extractingPath("$.data")
                .isEqualTo(Map.of("code", "CNY", "name", "위안", "minorUnit", 2, "isActive", false));
    }

    @Test
    void 원화를_끄면_400_CURRENCY_KRW_REQUIRED이고_이름도_바뀌지_않는다() {
        Cookie admin = logins.loginAs("ADMIN");

        MvcTestResult result = update(admin, "KRW", "{\"name\":\"원\",\"isActive\":false}");

        assertThat(result).hasStatus(HttpStatus.BAD_REQUEST);
        assertThat(result).bodyJson().extractingPath("$.code").isEqualTo("CURRENCY_KRW_REQUIRED");
        assertThat(result).bodyJson().extractingPath("$.message").isEqualTo("원화는 끌 수 없습니다");
        Map<String, Object> krw = jdbc.sql("SELECT name, is_active FROM cost.currencies WHERE code = 'KRW'")
                .query()
                .singleRow();
        assertThat(krw).containsEntry("name", "대한민국 원").containsEntry("is_active", true);
    }

    @Test
    void 원화를_켜는_것과_이름_바꾸기는_된다() {
        Cookie admin = logins.loginAs("ADMIN");

        MvcTestResult result = update(admin, "KRW", "{\"isActive\":true}");

        assertThat(result).hasStatus(HttpStatus.OK);
    }

    @Test
    void 없는_코드를_수정하면_404() {
        Cookie admin = logins.loginAs("ADMIN");

        MvcTestResult result = update(admin, "XYZ", "{\"name\":\"없음\"}");

        assertThat(result).hasStatus(HttpStatus.NOT_FOUND);
        assertThat(result).bodyJson().extractingPath("$.code").isEqualTo("NOT_FOUND");
    }

    @Test
    void 이름을_빈_값으로_바꾸면_400() {
        Cookie admin = logins.loginAs("ADMIN");

        MvcTestResult result = update(admin, "USD", "{\"name\":\"  \"}");

        assertThat(result).hasStatus(HttpStatus.BAD_REQUEST);
        assertThat(result).bodyJson().extractingPath("$.data.errors[0].field").isEqualTo("name");
    }

    private MvcTestResult add(Cookie session, String body) {
        return mvc.post()
                .uri("/api/v1/cost/currency")
                .cookie(session)
                .with(xsrf())
                .contentType(MediaType.APPLICATION_JSON)
                .content(body)
                .exchange();
    }

    private MvcTestResult update(Cookie session, String code, String body) {
        return mvc.patch()
                .uri("/api/v1/cost/currency/{code}", code)
                .cookie(session)
                .with(xsrf())
                .contentType(MediaType.APPLICATION_JSON)
                .content(body)
                .exchange();
    }

    @SuppressWarnings("unchecked")
    private static List<String> codes(MvcTestResult result) throws Exception {
        return JsonPath.read(result.getResponse().getContentAsString(StandardCharsets.UTF_8), "$.data[*].code");
    }
}
