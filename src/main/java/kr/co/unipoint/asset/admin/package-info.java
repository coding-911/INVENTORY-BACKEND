/** 승인·확인 대기함, 알림, 정합성 점검. 허용 의존은 docs/dev/directory-structure.md 5절. */
@ApplicationModule(allowedDependencies = {"user", "common :: api"})
package kr.co.unipoint.asset.admin;

import org.springframework.modulith.ApplicationModule;
