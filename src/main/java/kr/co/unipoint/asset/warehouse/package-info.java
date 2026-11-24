/** 창고·보관 위치. 허용 의존은 docs/dev/directory-structure.md 5절. */
@ApplicationModule(allowedDependencies = {"partner", "user", "common"})
package kr.co.unipoint.asset.warehouse;

import org.springframework.modulith.ApplicationModule;
