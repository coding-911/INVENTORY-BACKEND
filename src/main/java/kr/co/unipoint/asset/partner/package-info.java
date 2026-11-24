/** 거래처·담당자. 허용 의존은 docs/dev/directory-structure.md 5절. */
@ApplicationModule(allowedDependencies = {"user", "common"})
package kr.co.unipoint.asset.partner;

import org.springframework.modulith.ApplicationModule;
