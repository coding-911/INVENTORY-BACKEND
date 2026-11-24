/** 원가·판매 금액·마진. 허용 의존은 docs/dev/directory-structure.md 5절. */
@ApplicationModule(
        allowedDependencies = {
            "project",
            "product",
            "loan",
            "inventory",
            "delivery",
            "equipment",
            "allocation",
            "admin",
            "user",
            "common"
        })
package kr.co.unipoint.asset.cost;

import org.springframework.modulith.ApplicationModule;
