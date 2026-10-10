// Pipeline declarativo equivalente a .github/workflows/ci.yml (jobs `test`, `mutation` y `quarantine`).
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
// Solo las etapas 'Test' y 'Cuarentena (informativa)' las reciben. Los bloques `sh` usan comillas simples para
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
        // Suma de las etapas (CHK-12/14/17 ~1 min, mutación 10, suite 20,
        // cuarentena 20) con margen.
        timeout(time: 60, unit: 'MINUTES')
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

        // CHK-14: fuera de withCredentials, sin secrets ni navegador. Usa la fecha
        // del agente: una fila vencida rompe el build aunque el código no cambie.
        stage('Cuarentena reglada (CHK-14)') {
            steps {
                sh 'bash scripts/tests/check-quarantine-test.sh'
                sh 'bash scripts/check-quarantine.sh'
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

        // CHK-14: escenarios @quarantine, solo para informar (job `quarantine` de
        // GitHub Actions). catchError deja el build en SUCCESS y la etapa en
        // UNSTABLE si fallan: un `inestable` puede fallar y un `defecto-sut`
        // falla mientras el SUT no se corrija. Si alguno PASA, el log lo avisa:
        // un `defecto-sut` que pasa indica que el SUT cambió (revisar la spec).
        // Sin `junit` a propósito: no mezcla estos resultados con los de 'Test'
        // ni marca el build como UNSTABLE. Corre después de 'Test' (cuyo post ya
        // publicó y archivó sus reportes) y copia los suyos a quarantine-reports/.
        // Sin reintentos (CHK-02). Si 'Test' falla, esta etapa no corre.
        stage('Cuarentena (informativa)') {
            options {
                timeout(time: 20, unit: 'MINUTES')
            }
            steps {
                catchError(buildResult: 'SUCCESS', stageResult: 'UNSTABLE') {
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
rm -rf quarantine-reports
rc=0
git grep -qE '(^|[[:space:]])@quarantine([[:space:]]|$)' -- src/test/resources/features || rc=$?
case "$rc" in
  0) ;;
  1) echo "Sin escenarios con @quarantine: no hay nada que ejecutar."; exit 0 ;;
  *) echo "git grep terminó con $rc" >&2; exit 2 ;;
esac
bash scripts/check-required-secrets.sh
mvn_rc=0
./mvnw -B -ntp clean test -Dtest=RunnerTest -Dheadless=true -Dcucumber.filter.tags="@quarantine" || mvn_rc=$?
mkdir -p quarantine-reports
cp -R target/surefire-reports target/allure-results target/cucumber-report.html quarantine-reports/ 2>/dev/null || true
xml=target/surefire-reports/TEST-com.demo.runners.RunnerTest.xml
if [ ! -f "$xml" ]; then
  echo "La ejecución de @quarantine no produjo $xml" >&2
  exit 1
fi
suite="$(grep -o -m1 '<testsuite [^>]*>' "$xml")"
attr() { printf '%s\\n' "$suite" | grep -oE " $1=\\"[0-9]+\\"" | grep -oE '[0-9]+'; }
tests="$(attr tests)"; failures="$(attr failures)"; errors="$(attr errors)"; skipped="$(attr skipped)"
# Cucumber cuenta como skipped los escenarios que el filtro excluye.
run=$((tests - skipped))
passed=$((run - failures - errors))
echo "Cuarentena (CHK-14): ejecutados=$run pasaron=$passed fallaron=$failures errores=$errors"
[ "$run" -gt 0 ] || echo "AVISO: no se ejecutó ningún escenario @quarantine."
if [ "$passed" -gt 0 ]; then
  echo "AVISO: $passed escenario(s) en cuarentena pasaron: revisar docs/quarantine.md (un defecto-sut que pasa indica que el SUT cambió; un inestable no sale con un verde aislado)."
fi
exit "$mvn_rc"
'''
                    }
                }
            }
            post {
                always {
                    archiveArtifacts allowEmptyArchive: true,
                        artifacts: 'quarantine-reports/**',
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
