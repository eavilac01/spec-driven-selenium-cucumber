package com.demo.utils;

import com.demo.data.Credentials;

public final class CredentialsProvider {

    private CredentialsProvider() {
    }

    public static Credentials standardUser() {
        return new Credentials(
                SecretReader.getRequired("TEST_USER_STANDARD_USERNAME"),
                SecretReader.getRequired("TEST_USER_STANDARD_PASSWORD"));
    }

    public static Credentials lockedUser() {
        return new Credentials(
                SecretReader.getRequired("TEST_LOGIN_CASES_LOCKED_USER_USERNAME"),
                SecretReader.getRequired("TEST_LOGIN_CASES_LOCKED_USER_PASSWORD"));
    }

    public static Credentials invalidPassword() {
        return new Credentials(
                SecretReader.getRequired("TEST_LOGIN_CASES_INVALID_PASSWORD_USERNAME"),
                SecretReader.getRequired("TEST_LOGIN_CASES_INVALID_PASSWORD_PASSWORD"));
    }

    /** Usuario sintético inexistente con la contraseña válida de la cuenta estándar. */
    public static Credentials nonexistentUser() {
        return new Credentials(
                ConfigReader.getRequired("test.login.cases.nonexistent-user.username"),
                SecretReader.getRequired("TEST_USER_STANDARD_PASSWORD"));
    }

    /** Usuario vacío con la contraseña válida de la cuenta estándar. */
    public static Credentials emptyUsername() {
        return new Credentials("", SecretReader.getRequired("TEST_USER_STANDARD_PASSWORD"));
    }

    /** Usuario estándar con la contraseña vacía. */
    public static Credentials emptyPassword() {
        return new Credentials(SecretReader.getRequired("TEST_USER_STANDARD_USERNAME"), "");
    }

    public static Credentials emptyBoth() {
        return new Credentials("", "");
    }
}
