/** 차입·대여 (대차). 허용 의존은 docs/dev/directory-structure.md 5절. */
@ApplicationModule(
        allowedDependencies = {
            "inventory",
            "equipment",
            "allocation",
            "project",
            "delivery",
            "partner",
            "product",
            "admin",
            "user",
            "common :: api"
        })
package kr.co.unipoint.asset.loan;

import org.springframework.modulith.ApplicationModule;
