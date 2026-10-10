// Pipeline declarativo equivalente a .github/workflows/ci.yml (jobs `test` y `mutation`).
//
// Plugins requeridos (además de Pipeline y Git):
//   - Pipeline: Declarative            (pipeline, options, post)
//   - Credentials Binding              (withCredentials, string)
//   - Timestamper                      (timestamps)
//   - JUnit                            (junit)
//   - Workspace Cleanup                (cleanWs)
//   - Allure Jenkins Plugin            (allure), con una instalación de Allure
//                                      Commandline en Global Tool Configuration
//
// Herramientas (Manage Jenkins > Tools):
//   - JDK con nombre 'jdk-17' (Temurin 17, como setup-java en GitHub Actions).
//     Maven no hace falta: lo trae el Maven Wrapper (./mvnw).
//
// Agente: Linux con bash, git y Google Chrome instalados. Selenium Manager
// resuelve chromedriver. Se eligió `tools { jdk }` y no `agent { docker }`
// porque no hay una imagen oficial con JDK 17 y Chrome a la vez: una imagen
// propia sería un artefacto nuevo que mantener (P-06, requiere ADR).
//
// Credenciales (Manage Jenkins > Credentials), seis de tipo "Secret text".
// Cada ID es idéntico al nombre de la variable en .env.example:
//   TEST_USER_STANDARD_USERNAME
//   TEST_USER_STANDARD_PASSWORD
//   TEST_LOGIN_CASES_LOCKED_USER_USERNAME
//   TEST_LOGIN_CASES_LOCKED_USER_PASSWORD
//   TEST_LOGIN_CASES_INVALID_PASSWORD_USERNAME
//   TEST_LOGIN_CASES_INVALID_PASSWORD_PASSWORD
// Solo la etapa 'Test' las recibe. Los bloques `sh` usan comillas simples para
// que Groovy no interpole ningún valor: lo expande bash dentro del agente.

pipeline {
    agent any

    tools {
        jdk 'jdk-17'
    }

    options {
        // Checkout explícito en su propia etapa: queda visible y medible.
        skipDefaultCheckout(true)
        timestamps()
        // Suma de las etapas (CHK-12/17 ~1 min, mutación 10, suite 20) con margen.
        timeout(time: 40, unit: 'MINUTES')
        buildDiscarder(logRotator(numToKeepStr: '30', artifactNumToKeepStr: '10'))
        // El workspace y las sesiones del navegador no se comparten entre builds.
        disableConcurrentBuilds()
        // Pipeline corto y reproducible: no hace falta reanudarlo tras un
        // reinicio del controlador, así que se reduce la escritura a disco.
        durabilityHint('PERFORMANCE_OPTIMIZED')
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

        // CHK-17 (ADR-002, D6): fuera de withCredentials, sin secrets ni navegador.
        // La autoprueba crea su repositorio en un temporal fuera del workspace.
        stage('Capas (CHK-17)') {
            steps {
                sh 'bash scripts/tests/check-layers-test.sh'
                sh '''#!/usr/bin/env bash
set -euo pipefail
git --version
bash scripts/check-layers.sh
'''
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
                // `sh` usa /bin/sh (dash, sin pipefail): bash explícito para que
                // un fallo de PIT no quede oculto por `tee`. El workspace puede
                // persistir entre builds: sin reporte ni log previos.
                sh '''#!/usr/bin/env bash
set -euo pipefail
rm -rf target/pit-reports pit.log
./mvnw -B -ntp test-compile org.pitest:pitest-maven:mutationCoverage 2>&1 | tee pit.log
'''
                sh 'bash scripts/check-mutation-report.sh pit.log'
            }
            post {
                always {
                    archiveArtifacts allowEmptyArchive: true,
                        artifacts: 'target/pit-reports/**,pit.log',
                        fingerprint: true
                }
            }
        }

        // CHK-08: misma suite y mismo filtro que el job `test` de GitHub Actions.
        stage('Test') {
            options {
                timeout(time: 20, unit: 'MINUTES')
            }
            steps {
                sh '''#!/usr/bin/env bash
set -euo pipefail
java -version
./mvnw -B -ntp -version
'''
                withCredentials([
                    string(credentialsId: 'TEST_USER_STANDARD_USERNAME', variable: 'TEST_USER_STANDARD_USERNAME'),
                    string(credentialsId: 'TEST_USER_STANDARD_PASSWORD', variable: 'TEST_USER_STANDARD_PASSWORD'),
                    string(credentialsId: 'TEST_LOGIN_CASES_LOCKED_USER_USERNAME', variable: 'TEST_LOGIN_CASES_LOCKED_USER_USERNAME'),
                    string(credentialsId: 'TEST_LOGIN_CASES_LOCKED_USER_PASSWORD', variable: 'TEST_LOGIN_CASES_LOCKED_USER_PASSWORD'),
                    string(credentialsId: 'TEST_LOGIN_CASES_INVALID_PASSWORD_USERNAME', variable: 'TEST_LOGIN_CASES_INVALID_PASSWORD_USERNAME'),
                    string(credentialsId: 'TEST_LOGIN_CASES_INVALID_PASSWORD_PASSWORD', variable: 'TEST_LOGIN_CASES_INVALID_PASSWORD_PASSWORD')
                ]) {
                    sh '''#!/usr/bin/env bash
set -euo pipefail
bash scripts/check-required-secrets.sh
./mvnw -B -ntp clean test -Dheadless=true -Dcucumber.filter.tags="not @quarantine"
'''
                }
            }
            post {
                always {
                    // Sin resultados la etapa falla: un verde sin pruebas no vale.
                    junit allowEmptyResults: false,
                        testResults: 'target/surefire-reports/*.xml'
                    allure includeProperties: false,
                        results: [[path: 'target/allure-results']]
                    archiveArtifacts allowEmptyArchive: true,
                        artifacts: 'target/cucumber-report.html,target/surefire-reports/**,target/allure-results/**',
                        fingerprint: true
                }
            }
        }
    }

    post {
        cleanup {
            cleanWs deleteDirs: true, notFailBuild: true
        }
    }
}
