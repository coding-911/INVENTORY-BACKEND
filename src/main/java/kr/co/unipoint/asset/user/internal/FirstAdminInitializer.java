package kr.co.unipoint.asset.user.internal;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.core.env.Environment;
import org.springframework.core.env.Profiles;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Component;

/**
 * 앱이 켜질 때 사용 중인 관리자가 없으면 {@code ADMIN_LOGIN_ID}·{@code ADMIN_PASSWORD}(환경 변수)로 관리자 한 명을 만든다. 계정은
 * 관리자만 만들 수 있어서 첫 관리자는 이렇게 만든다. 처음 로그인하면 비밀번호를 바꿔야 한다 (API 명세서 1.14).
 *
 * <p>사용 중인 관리자가 없는데 아래에 해당하면 앱을 켜지 않는다 (ADR-17, 2026-11-25).
 *
 * <ul>
 *   <li>아이디·비밀번호가 없다: 켜져도 아무도 계정을 관리할 수 없다.
 *   <li>개발 PC({@code local} 프로필)가 아닌데 비밀번호가 개발용 기본값 {@code 1234}다: 누구나 관리자로 로그인해 비밀번호를 바꿔 버릴 수 있다.
 *       "처음 로그인하면 비밀번호를 바꿔야 한다"는 이것을 막지 못한다.
 * </ul>
 */
@Component
class FirstAdminInitializer implements ApplicationRunner {

    /** 개발 PC 기본값(application-local.yml). 개발 PC 밖에서는 쓰지 못한다. */
    static final String DEV_DEFAULT_PASSWORD = "1234";

    private static final Logger log = LoggerFactory.getLogger(FirstAdminInitializer.class);
    private static final String NAME = "관리자";

    private final UserAccountStore store;
    private final PasswordEncoder passwordEncoder;
    private final Environment environment;
    private final String loginId;
    private final String password;

    FirstAdminInitializer(
            UserAccountStore store,
            PasswordEncoder passwordEncoder,
            Environment environment,
            @Value("${asset.first-admin.login-id:}") String loginId,
            @Value("${asset.first-admin.password:}") String password) {
        this.store = store;
        this.passwordEncoder = passwordEncoder;
        this.environment = environment;
        this.loginId = loginId;
        this.password = password;
    }

    @Override
    public void run(ApplicationArguments args) {
        if (store.hasActiveAdmin()) {
            return;
        }
        if (loginId.isBlank() || password.isBlank()) {
            throw new IllegalStateException("사용 중인 관리자가 없습니다. ADMIN_LOGIN_ID·ADMIN_PASSWORD 환경 변수를 넣고 다시 켜 주세요");
        }
        if (password.equals(DEV_DEFAULT_PASSWORD) && !environment.acceptsProfiles(Profiles.of("local"))) {
            throw new IllegalStateException("개발용 기본 비밀번호로는 첫 관리자를 만들 수 없습니다. ADMIN_PASSWORD에 다른 값을 넣고 다시 켜 주세요");
        }
        if (store.loginIdExists(loginId)) {
            log.warn("사용 중인 관리자가 없지만 다른 계정이 이미 로그인 ID({})를 씁니다. 첫 관리자를 만들지 않았습니다", loginId);
            return;
        }
        store.createFirstAdmin(loginId, NAME, passwordEncoder.encode(password));
        log.info("사용 중인 관리자가 없어 관리자를 만들었습니다(로그인 ID: {}). 처음 로그인하면 비밀번호를 바꿔야 합니다", loginId);
    }
}
