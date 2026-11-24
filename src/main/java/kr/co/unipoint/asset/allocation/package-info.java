/** 스탁·프로젝트 배정. 허용 의존은 docs/dev/directory-structure.md 5절. */
@ApplicationModule(allowedDependencies = {"inventory", "equipment", "project", "delivery", "product", "common"})
package kr.co.unipoint.asset.allocation;

import org.springframework.modulith.ApplicationModule;
