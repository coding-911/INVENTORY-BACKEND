/** 발주·입고 잔량, 납품, 직납. 허용 의존은 docs/dev/directory-structure.md 5절. */
@ApplicationModule(allowedDependencies = {"project", "inventory", "equipment", "product", "partner", "common"})
package kr.co.unipoint.asset.delivery;

import org.springframework.modulith.ApplicationModule;
