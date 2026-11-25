package kr.co.unipoint.asset.user.internal;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatCode;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import org.junit.jupiter.api.Test;
import org.springframework.boot.DefaultApplicationArguments;
import org.springframework.mock.env.MockEnvironment;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;

/** 사용 중인 관리자가 없을 때 첫 관리자를 만들 수 없는 설정이면 앱을 켜지 않는다 (ADR-17). */
class FirstAdminInitializerRuleTest {

    private final UserAccountStore store = mock(UserAccountStore.class);

    @Test
    void 관리자가_없는데_아이디나_비밀번호가_없으면_켜지지_않는다() {
        when(store.hasActiveAdmin()).thenReturn(false);

        assertThatThrownBy(() -> run("admin", "", "prod"))
                .isInstanceOf(IllegalStateException.class)
                .hasMessageContaining("ADMIN_LOGIN_ID·ADMIN_PASSWORD");
        assertThatThrownBy(() -> run("", "secret", "prod")).isInstanceOf(IllegalStateException.class);
        verify(store, never()).createFirstAdmin(anyString(), anyString(), anyString());
    }

    @Test
    void 개발_PC가_아닌데_비밀번호가_개발용_기본값이면_켜지지_않는다() {
        when(store.hasActiveAdmin()).thenReturn(false);

        assertThatThrownBy(() -> run("admin", "1234", "prod"))
                .isInstanceOf(IllegalStateException.class)
                .hasMessageContaining("개발용 기본 비밀번호");
        assertThatThrownBy(() -> run("admin", "1234")).isInstanceOf(IllegalStateException.class);
        verify(store, never()).createFirstAdmin(anyString(), anyString(), anyString());
    }

    @Test
    void 개발_PC에서는_개발용_기본값으로_만든다() {
        when(store.hasActiveAdmin()).thenReturn(false);

        assertThatCode(() -> run("admin", "1234", "local")).doesNotThrowAnyException();
        verify(store).createFirstAdmin(eq("admin"), anyString(), anyString());
    }

    @Test
    void 비밀번호가_해시_한도_72바이트를_넘으면_켜지지_않는다() {
        when(store.hasActiveAdmin()).thenReturn(false);

        assertThatThrownBy(() -> run("admin", "가".repeat(25), "prod"))
                .isInstanceOf(IllegalStateException.class)
                .hasMessageContaining("너무 깁니다");
        verify(store, never()).createFirstAdmin(anyString(), anyString(), anyString());
    }

    /**
     * 72바이트 한도를 새로 해시하는 곳(비밀번호 변경·첫 관리자)에만 두고 로그인에는 두지 않는 이유. Spring Security가 이 동작을 바꾸면 이 테스트가
     * 알려 준다.
     */
    @Test
    void BCrypt는_72바이트를_넘으면_해시할_때는_예외를_던지고_비교할_때는_앞_72바이트만_본다() {
        BCryptPasswordEncoder encoder = new BCryptPasswordEncoder(4);
        String hash = encoder.encode("a".repeat(72));

        assertThatThrownBy(() -> encoder.encode("a".repeat(73))).isInstanceOf(IllegalArgumentException.class);
        assertThat(encoder.matches("a".repeat(73), hash)).isTrue();
        assertThat(encoder.matches("b".repeat(73), hash)).isFalse();
    }

    @Test
    void 사용_중인_관리자가_있으면_설정이_없어도_그대로_켜진다() {
        when(store.hasActiveAdmin()).thenReturn(true);

        assertThatCode(() -> run("", "", "prod")).doesNotThrowAnyException();
        assertThatCode(() -> run("admin", "1234", "prod")).doesNotThrowAnyException();
        verify(store, never()).createFirstAdmin(anyString(), anyString(), anyString());
    }

    private void run(String loginId, String password, String... profiles) {
        MockEnvironment environment = new MockEnvironment();
        environment.setActiveProfiles(profiles);
        new FirstAdminInitializer(store, new BCryptPasswordEncoder(4), environment, loginId, password)
                .run(new DefaultApplicationArguments());
    }
}
