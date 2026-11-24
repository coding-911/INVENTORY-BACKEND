/** 홈 집계 (읽기 전용). 허용 의존은 docs/dev/directory-structure.md 5절. */
@ApplicationModule(allowedDependencies = {"project", "inventory", "product", "admin", "user", "common :: api"})
package kr.co.unipoint.asset.dashboard;

import org.springframework.modulith.ApplicationModule;
