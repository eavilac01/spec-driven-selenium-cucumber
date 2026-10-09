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

        stage('Traceability SDD (CHK-12)') {
            steps {
                sh 'bash scripts/check-traceability.sh'
            }
        }

        // CHK-11 (ADR-001, D5): fuera de withCredentials, sin secrets ni navegador.
        // Va antes de 'Test' porque `clean test` borra target/pit-reports.
        stage('Mutation (CHK-11)') {
            options {
                timeout(time: 10, unit: 'MINUTES')
            }
            steps {
                sh 'bash scripts/check-unit-purity.sh'
                // El workspace persiste entre builds: sin reporte ni log previos.
                sh 'rm -rf target/pit-reports pit.log'
                sh '''#!/usr/bin/env bash
set -euo pipefail
./mvnw -B -ntp test-compile org.pitest:pitest-maven:mutationCoverage 2>&1 | tee pit.log
'''
                sh 'bash scripts/check-mutation-report.sh pit.log'
            }
            post {
                always {
                    archiveArtifacts allowEmptyArchive: true,
                        artifacts: 'target/pit-reports/**',
                        fingerprint: true
                }
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
