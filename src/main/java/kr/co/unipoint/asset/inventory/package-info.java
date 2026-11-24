/** 재고 원장 (처리 묶음, 원장, 재고 조회). 허용 의존은 docs/dev/directory-structure.md 5절. */
@ApplicationModule(allowedDependencies = {"product", "warehouse", "admin", "user", "common :: api"})
package kr.co.unipoint.asset.inventory;

import org.springframework.modulith.ApplicationModule;
