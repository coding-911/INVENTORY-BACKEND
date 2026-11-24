package kr.co.unipoint.asset;

import org.junit.jupiter.api.Test;
import org.springframework.modulith.core.ApplicationModules;
import org.springframework.modulith.docs.Documenter;

/** 모듈 경계와 의존 규칙 검사 (docs/dev/directory-structure.md 5절). */
class ModularityTest {

    private final ApplicationModules modules = ApplicationModules.of(AssetApplication.class);

    @Test
    void verifiesModularStructure() {
        modules.verify(); // internal 참조, 순환 의존, 허용되지 않은 의존 시 실패
    }

    @Test
    void writesDocumentation() {
        new Documenter(modules).writeDocumentation(); // build/spring-modulith-docs
    }
}
