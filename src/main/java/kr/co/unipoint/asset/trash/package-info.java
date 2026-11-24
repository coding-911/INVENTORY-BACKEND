/** 삭제 목록·복구. 허용 의존은 docs/dev/directory-structure.md 5절. */
@ApplicationModule(allowedDependencies = {"admin", "common"})
package kr.co.unipoint.asset.trash;

import org.springframework.modulith.ApplicationModule;
