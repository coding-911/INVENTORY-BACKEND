/** 시리얼 개별 장비, 보증. 허용 의존은 docs/dev/directory-structure.md 5절. */
@ApplicationModule(
        allowedDependencies = {
            "product",
            "warehouse",
            "inventory",
            "partner",
            "project",
            "admin",
            "user",
            "common :: api"
        })
package kr.co.unipoint.asset.equipment;

import org.springframework.modulith.ApplicationModule;
