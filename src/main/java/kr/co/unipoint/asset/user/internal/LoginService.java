package kr.co.unipoint.asset.user.internal;

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

/** 아이디·비밀번호 확인과 내 정보 (API 목록 "로그인·로그아웃", "내 정보"). */
@Service
public class LoginService {

    private final UserAccountStore store;
    private final PasswordEncoder passwordEncoder;
    private final String dummyHash;

    LoginService(UserAccountStore store, PasswordEncoder passwordEncoder) {
        this.store = store;
        this.passwordEncoder = passwordEncoder;
        this.dummyHash = passwordEncoder.encode("not-a-password");
    }

    /**
     * 아이디·비밀번호가 맞고 사용 중인 계정이면 마지막 로그인 시각을 남긴다. 없는 아이디, 틀린 비밀번호, 사용 중지 계정은 모두 같은 401
     * {@code LOGIN_FAILED}다. 어느 경우인지 알려 주면 있는 아이디를 알아낼 수 있기 때문이다. 실패 잠금은 없다 (#100).
     */
    @Transactional
    public LoginResult login(String loginId, String password) {
        Optional<Account> found = store.findByLoginId(loginId);
        // 없는 아이디도 비밀번호 비교 시간을 똑같이 써서 응답 시간으로 있는 아이디를 알아내지 못하게 한다
        boolean matches = passwordEncoder.matches(
                password, found.map(Account::passwordHash).orElse(dummyHash));
        if (found.isEmpty() || !matches || !found.get().active()) {
            throw new BusinessException(ErrorCode.LOGIN_FAILED);
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
