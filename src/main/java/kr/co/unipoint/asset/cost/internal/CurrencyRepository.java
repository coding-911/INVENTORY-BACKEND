package kr.co.unipoint.asset.cost.internal;

import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;

interface CurrencyRepository extends JpaRepository<Currency, String> {

    List<Currency> findAllByOrderByCode();

    List<Currency> findByActiveOrderByCode(boolean active);
}
