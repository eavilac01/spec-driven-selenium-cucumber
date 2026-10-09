pipeline {
    agent any

    options {
        skipDefaultCheckout(true)
        timestamps()
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Test') {
            steps {
                sh 'java -version'
                sh './mvnw -version'
                withCredentials([
                    usernamePassword(
                        credentialsId: 'saucedemo-standard-user',
                        usernameVariable: 'TEST_USER_STANDARD_USERNAME',
                        passwordVariable: 'TEST_USER_STANDARD_PASSWORD'
                    ),
                    usernamePassword(
                        credentialsId: 'saucedemo-locked-user',
                        usernameVariable: 'TEST_LOGIN_CASES_LOCKED_USER_USERNAME',
                        passwordVariable: 'TEST_LOGIN_CASES_LOCKED_USER_PASSWORD'
                    ),
                    usernamePassword(
                        credentialsId: 'saucedemo-invalid-login',
                        usernameVariable: 'TEST_LOGIN_CASES_INVALID_PASSWORD_USERNAME',
                        passwordVariable: 'TEST_LOGIN_CASES_INVALID_PASSWORD_PASSWORD'
                    )
                ]) {
                    sh './mvnw -B -ntp clean test -Dheadless=true'
                }
            }
        }
    }

    post {
        always {
            junit allowEmptyResults: true,
                testResults: 'target/surefire-reports/*.xml'
            allure includeProperties: false,
                results: [[path: 'target/allure-results']]
            archiveArtifacts allowEmptyArchive: true,
                artifacts: 'target/cucumber-report.html',
                fingerprint: true
        }
    }
}
