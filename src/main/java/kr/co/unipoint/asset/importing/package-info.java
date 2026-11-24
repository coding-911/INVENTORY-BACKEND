/** 증빙 첨부. 허용 의존은 docs/dev/directory-structure.md 5절. */
@ApplicationModule(allowedDependencies = {"project", "user", "admin", "common"})
package kr.co.unipoint.asset.importing;

import org.springframework.modulith.ApplicationModule;
