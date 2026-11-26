package kr.co.unipoint.asset.user;

import static org.assertj.core.api.Assertions.assertThat;

import java.util.Arrays;
import java.util.List;
import kr.co.unipoint.asset.support.TestcontainersConfiguration;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.context.annotation.Import;
import org.springframework.jdbc.core.simple.JdbcClient;

/** V5가 넣은 권한 목록과 기본 역할 (권한 매트릭스 1.2·1.5, 확정 사항 #106). */
@SpringBootTest
@Import(TestcontainersConfiguration.class)
class RolePermissionSeedTest {

    @Autowired
    JdbcClient jdbc;

    @Test
    void INV88_DB의_권한_목록과_코드의_Permission이_같고_순서도_같다() {
        List<String> db = jdbc.sql("SELECT code FROM auth.permissions ORDER BY sort_order")
                .query(String.class)
                .list();

        assertThat(db)
                .containsExactlyElementsOf(
                        Arrays.stream(Permission.values()).map(Enum::name).toList());
    }

    @Test
    void INV88_관리자_역할은_모든_권한을_갖는다() {
        assertThat(permissionsOf("ADMIN"))
                .containsExactlyElementsOf(
                        Arrays.stream(Permission.values()).map(Enum::name).toList());
    }

    @Test
    void 기본_역할의_권한은_권한_매트릭스_1_5와_같다() {
        List<String> operator = List.of("PARTNER_MANAGE", "PRODUCT_MANAGE", "DOCUMENT_MANAGE", "STOCK_OPERATE");

        assertThat(permissionsOf("OPERATOR_BASIC")).containsExactlyElementsOf(operator);
        assertThat(permissionsOf("OPERATOR_COST_VIEW"))
                .containsExactly("PARTNER_MANAGE", "PRODUCT_MANAGE", "DOCUMENT_MANAGE", "STOCK_OPERATE", "COST_VIEW");
        assertThat(permissionsOf("OPERATOR_COST_EDIT"))
                .containsExactly(
                        "PARTNER_MANAGE",
                        "PRODUCT_MANAGE",
                        "DOCUMENT_MANAGE",
                        "STOCK_OPERATE",
                        "COST_VIEW",
                        "COST_EDIT");
        assertThat(permissionsOf("USER_BASIC")).isEmpty();
        assertThat(permissionsOf("USER_COST_VIEW")).containsExactly("COST_VIEW");
    }

    @Test
    void 기본_역할의_이름() {
        List<String> names = jdbc.sql("""
                        SELECT name FROM auth.roles
                        WHERE code IN ('ADMIN', 'OPERATOR_BASIC', 'OPERATOR_COST_VIEW', 'OPERATOR_COST_EDIT',
                                       'USER_BASIC', 'USER_COST_VIEW')
                        ORDER BY array_position(ARRAY['ADMIN', 'OPERATOR_BASIC', 'OPERATOR_COST_VIEW',
                                                      'OPERATOR_COST_EDIT', 'USER_BASIC', 'USER_COST_VIEW'], code::text)
                        """).query(String.class).list();

        assertThat(names).containsExactly("관리자", "일반 운영자", "영업 운영자", "정산 운영자", "일반 사용자", "회계 사용자");
    }

    private List<String> permissionsOf(String roleCode) {
        return jdbc.sql("""
                        SELECT p.code FROM auth.roles r
                        JOIN auth.role_permissions rp ON rp.role_id = r.id
                        JOIN auth.permissions p ON p.code = rp.permission_code
                        WHERE r.code = :code AND r.deleted_at IS NULL
                        ORDER BY p.sort_order
                        """).param("code", roleCode).query(String.class).list();
    }
}
