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
}
