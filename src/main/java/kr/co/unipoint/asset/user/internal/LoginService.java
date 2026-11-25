package kr.co.unipoint.asset.user.internal;

import java.nio.charset.StandardCharsets;
import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import kr.co.unipoint.asset.common.api.BusinessException;
import kr.co.unipoint.asset.common.api.ErrorCode;
import kr.co.unipoint.asset.user.internal.UserAccountStore.Account;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/** 아이디·비밀번호 확인, 내 정보, 본인 비밀번호 변경 (API 목록 "로그인·로그아웃", "내 정보", "본인 비밀번호 변경"). */
@Service
public class LoginService {

    /**
     * 새로 해시하는 비밀번호의 최대 바이트(UTF-8). 비밀번호 규칙이 아니라 기술 한도다: BCrypt는 72바이트까지만 다루고, Spring Security는 더 긴
     * 값을 해시하면 예외를 던진다(그대로 두면 500). 비교할 때는 예외 없이 앞 72바이트만 보므로 로그인에는 두지 않는다. 영문 72자, 한글 24자
     * (2026-11-25).
     */
    public static final int PASSWORD_MAX_BYTES = 72;

    private final UserAccountStore store;
    private final PasswordEncoder passwordEncoder;
    private final String dummyHash;

    LoginService(UserAccountStore store, PasswordEncoder passwordEncoder) {
        this.store = store;
        this.passwordEncoder = passwordEncoder;
        this.dummyHash = passwordEncoder.encode("not-a-password");
    }

    public static boolean fitsPasswordHash(String password) {
        return password.getBytes(StandardCharsets.UTF_8).length <= PASSWORD_MAX_BYTES;
    }

    /**
     * 아이디·비밀번호가 맞고 사용 중인 계정이면 마지막 로그인 시각을 남긴다. 실패 잠금은 없다 (#100).
     *
     * <ul>
     *   <li>없는 아이디·틀린 비밀번호: 같은 401 {@code LOGIN_FAILED}. 구분해 알려 주면 있는 아이디를 알아낼 수 있다.
     *   <li>비밀번호는 맞는데 사용 중지된 계정: 403 {@code ACCOUNT_INACTIVE}. 비밀번호를 아는 사람에게만 보이므로 아이디가 드러나지 않고, 다시
     *       입력해도 소용없으니 관리자에게 문의하라고 알려 준다 (2026-11-25).
     * </ul>
     */
    @Transactional
    public LoginResult login(String loginId, String password) {
        Optional<Account> found = store.findByLoginId(loginId);
        // 없는 아이디도 비밀번호 비교 시간을 똑같이 써서 응답 시간으로 있는 아이디를 알아내지 못하게 한다
        boolean matches = passwordEncoder.matches(
                password, found.map(Account::passwordHash).orElse(dummyHash));
        if (found.isEmpty() || !matches) {
            throw new BusinessException(ErrorCode.LOGIN_FAILED);
        }
        if (!found.get().active()) {
            throw new BusinessException(ErrorCode.ACCOUNT_INACTIVE);
        }
        Account account = found.get();
        Instant loginAt = store.recordLogin(account.id());
        return new LoginResult(account.toLoginUser(loginAt), profile(account));
    }

    /** 세션 확인을 통과한 사용자만 부르므로 없으면(그사이 삭제) 401이다. */
    @Transactional(readOnly = true)
    public UserProfile me(UUID id) {
        return store.findById(id)
                .map(LoginService::profile)
                .orElseThrow(() -> new BusinessException(ErrorCode.UNAUTHENTICATED));
    }

    /**
     * 지금 비밀번호가 맞으면 새 비밀번호로 바꾸고, 비밀번호 변경 필요 상태를 풀고, {@code tokens_valid_after}를 지금으로 기록해 이 사용자의 모든
     * 세션(이 요청의 세션 포함)을 끊는다 (API 목록 "본인 비밀번호 변경", #100, INV-80). 비밀번호 규칙은 없다. 지금 비밀번호와 같아도 바꾼다.
     *
     * <p>그사이 다른 요청이 비밀번호를 먼저 바꿨으면 지금 비밀번호가 맞지 않는 것과 같으므로 {@code PASSWORD_MISMATCH}다.
     */
    @Transactional
    public void changePassword(UUID id, String currentPassword, String newPassword) {
        Account account = store.findById(id).orElseThrow(() -> new BusinessException(ErrorCode.UNAUTHENTICATED));
        if (!passwordEncoder.matches(currentPassword, account.passwordHash())) {
            throw new BusinessException(ErrorCode.PASSWORD_MISMATCH);
        }
        if (!store.changePassword(id, account.passwordHash(), passwordEncoder.encode(newPassword))) {
            throw new BusinessException(ErrorCode.PASSWORD_MISMATCH);
        }
    }

    private static UserProfile profile(Account account) {
        return new UserProfile(
                account.id(),
                account.loginId(),
                account.name(),
                account.roles(),
                account.permissions(),
                account.mustChangePassword());
    }

    public record LoginResult(LoginUser user, UserProfile profile) {}

    public record UserProfile(
            UUID id,
            String loginId,
            String name,
            List<String> roles,
            List<String> permissions,
            boolean mustChangePassword) {}
}
