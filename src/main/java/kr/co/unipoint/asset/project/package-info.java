/** 프로젝트, 매입·매출·선발주 문서, 비교. 허용 의존은 docs/dev/directory-structure.md 5절. */
@ApplicationModule(allowedDependencies = {"product", "partner", "admin", "user", "common"})
package kr.co.unipoint.asset.project;

import org.springframework.modulith.ApplicationModule;
