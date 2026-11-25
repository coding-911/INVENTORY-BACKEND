package kr.co.unipoint.asset.user.internal;

import java.sql.Array;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.time.Instant;
import java.time.OffsetDateTime;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

/** 로그인에 필요한 {@code auth} 스키마 읽기·쓰기 (docs/db/table-definition.md 3절). 삭제된 사용자는 없는 것으로 본다. */
@Component
class UserAccountStore {

    private static final String ACCOUNT_COLUMNS = """
            SELECT u.id, u.login_id, u.name, u.password_hash, u.is_active, u.must_change_password,
                   ARRAY(SELECT r.code FROM auth.user_roles ur JOIN auth.roles r ON r.id = ur.role_id
                         WHERE ur.user_id = u.id ORDER BY r.code) AS roles,
                   ARRAY(SELECT p.permission FROM auth.user_permissions p
                         WHERE p.user_id = u.id ORDER BY p.permission) AS permissions
            FROM auth.users u
            """;

    private final JdbcClient jdbc;

    UserAccountStore(JdbcClient jdbc) {
        this.jdbc = jdbc;
    }

    Optional<Account> findByLoginId(String loginId) {
        return jdbc.sql(ACCOUNT_COLUMNS + "WHERE u.login_id = :loginId AND u.deleted_at IS NULL")
                .param("loginId", loginId)
                .query(UserAccountStore::account)
                .optional();
    }

    Optional<Account> findById(UUID id) {
        return jdbc.sql(ACCOUNT_COLUMNS + "WHERE u.id = :id AND u.deleted_at IS NULL")
                .param("id", id)
                .query(UserAccountStore::account)
                .optional();
    }

    /** 요청마다 세션이 아직 유효한지 볼 값. */
    Optional<SessionState> findSessionState(UUID id) {
        return jdbc.sql("""
                        SELECT is_active, tokens_valid_after, must_change_password
                        FROM auth.users
                        WHERE id = :id AND deleted_at IS NULL
                        """)
                .param("id", id)
                .query((rs, rowNum) -> new SessionState(
                        rs.getBoolean("is_active"),
                        toInstant(rs.getObject("tokens_valid_after", OffsetDateTime.class)),
                        rs.getBoolean("must_change_password")))
                .optional();
    }

    /** 마지막 로그인 시각을 DB 시각으로 남기고 그 시각을 돌려준다. {@code tokens_valid_after}와 같은 시계로 비교하기 위해서다. */
    Instant recordLogin(UUID id) {
        return jdbc.sql("UPDATE auth.users SET last_login_at = now() WHERE id = :id RETURNING last_login_at")
                .param("id", id)
                .query((rs, rowNum) -> rs.getObject(1, OffsetDateTime.class).toInstant())
                .single();
    }

    boolean hasActiveAdmin() {
        return jdbc.sql("""
                        SELECT EXISTS (
                            SELECT 1 FROM auth.users u
                            JOIN auth.user_roles ur ON ur.user_id = u.id
                            JOIN auth.roles r ON r.id = ur.role_id
                            WHERE r.code = 'ADMIN' AND u.is_active AND u.deleted_at IS NULL)
                        """).query(Boolean.class).single();
    }

    boolean loginIdExists(String loginId) {
        return jdbc.sql("SELECT EXISTS (SELECT 1 FROM auth.users WHERE login_id = :loginId AND deleted_at IS NULL)")
                .param("loginId", loginId)
                .query(Boolean.class)
                .single();
    }

    /** 첫 관리자. 만든 사람이 없으므로 {@code created_by}는 자기 ID다. 처음 로그인하면 비밀번호를 바꿔야 한다. */
    @Transactional
    UUID createFirstAdmin(String loginId, String name, String passwordHash) {
        UUID id = jdbc.sql("""
                        WITH new_user AS (SELECT uuidv7() AS id)
                        INSERT INTO auth.users (id, login_id, name, password_hash, must_change_password, created_by)
                        SELECT id, :loginId, :name, :passwordHash, true, id FROM new_user
                        RETURNING id
                        """)
                .param("loginId", loginId)
                .param("name", name)
                .param("passwordHash", passwordHash)
                .query(UUID.class)
                .single();
        jdbc.sql("""
                        INSERT INTO auth.user_roles (user_id, role_id)
                        SELECT :id, id FROM auth.roles WHERE code = 'ADMIN'
                        """).param("id", id).update();
        return id;
    }

    private static Account account(ResultSet rs, int rowNum) throws SQLException {
        return new Account(
                rs.getObject("id", UUID.class),
                rs.getString("login_id"),
                rs.getString("name"),
                rs.getString("password_hash"),
                rs.getBoolean("is_active"),
                rs.getBoolean("must_change_password"),
                strings(rs.getArray("roles")),
                strings(rs.getArray("permissions")));
    }

    private static List<String> strings(Array array) throws SQLException {
        return List.of((String[]) array.getArray());
    }

    private static Instant toInstant(OffsetDateTime value) {
        return value == null ? null : value.toInstant();
    }

    record Account(
            UUID id,
            String loginId,
            String name,
            String passwordHash,
            boolean active,
            boolean mustChangePassword,
            List<String> roles,
            List<String> permissions) {}

    /**
     * @param tokensValidAfter 이보다 먼저 로그인한 세션은 끊는다. 없으면 null
     */
    record SessionState(boolean active, Instant tokensValidAfter, boolean mustChangePassword) {

        boolean allows(Instant loginAt) {
            return active && (tokensValidAfter == null || !loginAt.isBefore(tokensValidAfter));
        }
    }
}
