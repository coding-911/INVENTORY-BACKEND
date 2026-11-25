package kr.co.unipoint.asset.user.web.request;

import jakarta.validation.Constraint;
import jakarta.validation.ConstraintValidator;
import jakarta.validation.ConstraintValidatorContext;
import jakarta.validation.Payload;
import java.lang.annotation.ElementType;
import java.lang.annotation.Retention;
import java.lang.annotation.RetentionPolicy;
import java.lang.annotation.Target;
import kr.co.unipoint.asset.user.internal.LoginService;

/**
 * 비밀번호가 해시할 수 있는 길이({@link LoginService#PASSWORD_MAX_BYTES}, UTF-8 72바이트) 안인지 본다. 비밀번호 규칙이 아니라 기술 한도다(#100은
 * 그대로). 빈 값은 {@code @NotBlank}가 본다.
 */
@Target(ElementType.FIELD)
@Retention(RetentionPolicy.RUNTIME)
@Constraint(validatedBy = PasswordMaxBytes.Validator.class)
public @interface PasswordMaxBytes {

    String message() default "비밀번호는 72바이트(영문 72자, 한글 24자)까지 넣을 수 있습니다";

    Class<?>[] groups() default {};

    Class<? extends Payload>[] payload() default {};

    class Validator implements ConstraintValidator<PasswordMaxBytes, String> {

        @Override
        public boolean isValid(String value, ConstraintValidatorContext context) {
            return value == null || LoginService.fitsPasswordHash(value);
        }
    }
}
