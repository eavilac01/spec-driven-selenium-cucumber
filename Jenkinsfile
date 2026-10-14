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
// Solo las etapas 'Test' y 'Cuarentena (CHK-14)' las reciben. Los bloques `sh` usan comillas simples para
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
        // Suma de las etapas (CHK-12/14/17/20 ~1 min, mutación 10, suite 20,
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

        // Portabilidad de awk: la estática no necesita gawk. Las autopruebas que
        // usan awk corren con cada implementación instalada en el agente (sin
        // --require: GitHub Actions exige mawk, gawk y gawk --posix).
        stage('Portabilidad de awk') {
            steps {
                sh 'bash scripts/tests/check-awk-portability-test.sh'
                sh 'bash scripts/check-awk-portability.sh'
                sh 'bash scripts/tests/run-with-each-awk-test.sh'
            }
        }

        // CHK-17 (ADR-002, D6): fuera de withCredentials, sin secrets ni navegador.
        // La autoprueba crea su repositorio en un temporal fuera del workspace.
        stage('Capas (CHK-17)') {
            steps {
                sh 'bash scripts/run-with-each-awk.sh -- bash scripts/tests/check-layers-test.sh'
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
                sh 'bash scripts/run-with-each-awk.sh -- bash scripts/tests/check-quarantine-test.sh'
                sh 'bash scripts/run-with-each-awk.sh -- bash scripts/tests/evaluate-quarantine-run-test.sh'
                sh 'bash scripts/check-quarantine.sh'
            }
        }

        // ADR-003, R-2: autoprueba del control de las etapas 'Test' y
        // 'Cuarentena (CHK-14)', con logs sintéticos (sin awk ni secrets).
        stage('Esperados por -D (ADR-003, R-2)') {
            steps {
                sh 'bash scripts/tests/check-no-expected-override-test.sh'
            }
        }

        // ADR-004, D5: autoprueba del control de la etapa 'Test' (CHK-20), con
        // reportes sintéticos en un repositorio temporal fuera del workspace
        // (sin awk ni secrets).
        stage('Contrato ejecutado, autoprueba (CHK-20)') {
            steps {
                sh 'bash scripts/tests/check-contract-ran-test.sh'
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
        // ADR-003, R-2: después de Maven, aunque falle, el log no puede tener el
        // aviso de D3 (un esperado sobrescrito por -D). CHK-20 (ADR-004, D5):
        // también aunque Maven falle, las pruebas de contrato tienen su reporte
        // con tests > 0 y sin omitidas, fallos ni errores. El rc de Maven no se
        // tapa: si Maven falla, la etapa sale con su rc; si no, con el del
        // primer control que falle. test.log no se archiva: los artefactos no
        // pasan por el enmascarado de credenciales de la consola.
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
rm -f test.log
bash scripts/check-required-secrets.sh
set +e
./mvnw -B -ntp clean test -Dheadless=true -Dcucumber.filter.tags="not @quarantine" 2>&1 | tee test.log
st=("${PIPESTATUS[@]}")
set -e
mvn_rc="${st[0]}"
override_rc=0
bash scripts/check-no-expected-override.sh test.log || override_rc=$?
contract_rc=0
bash scripts/check-contract-ran.sh target/surefire-reports || contract_rc=$?
if [ "${st[1]}" -ne 0 ]; then
  echo "tee terminó con ${st[1]}: el log de Maven está incompleto" >&2
  exit 1
fi
if [ "$mvn_rc" -ne 0 ]; then
  exit "$mvn_rc"
fi
if [ "$override_rc" -ne 0 ]; then
  exit "$override_rc"
fi
exit "$contract_rc"
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

        // CHK-14: escenarios @quarantine (job `quarantine` de GitHub Actions), en una
        // sola ejecución (sin reintentos, CHK-02). scripts/evaluate-quarantine-run.sh
        // cruza el rc de Maven, su log y el XML de Surefire con docs/quarantine.md:
        //   rc 0 -> etapa en verde: un `defecto-sut` que falla por aserción (lo
        //           esperado) o un `inestable` que falla por aserción o pasa
        //           (informativo); el mensaje queda en el log.
        //   rc 3 -> aviso: etapa UNSTABLE con build SUCCESS, como el ::warning::
        //           de GitHub. Un `defecto-sut` PASA (el SUT pudo haberse
        //           corregido) o un `inestable` termina con error (excepción o
        //           timeout: revisar su diagnóstico); el log nombra el @AC-.
        //   otro -> error real (la cuarentena no mide nada o se rompe: excepción o
        //           timeout de un `defecto-sut`, cero escenarios, sin XML, Maven
        //           falló por otra causa, un escenario sin fila):
        //           FAILURE de la etapa y del build, como el job rojo de GitHub. Se
        //           rompe el build a propósito: con la etapa sola en rojo y el build
        //           en verde, una cuarentena que no mide pasaría inadvertida.
        // Sin `junit` a propósito: no mezcla estos resultados con los de 'Test'.
        // Corre después de 'Test' (cuyo post ya publicó y archivó sus reportes) y
        // copia los suyos a quarantine-reports/. Si 'Test' falla, esta etapa no corre.
        // quarantine.log queda en la raíz del workspace y no se archiva, igual que
        // test.log en 'Test': los artefactos no pasan por el enmascarado de
        // credenciales de la consola (el log ya está, enmascarado, en la consola).
        // ADR-003, R-2: tras el evaluador corre el control del aviso de D3. Un
        // error real del evaluador conserva su rc; si el evaluador da 0 o 3 y el
        // log tiene el aviso (o no se puede evaluar), sale con el rc del control
        // (1 o 2): FAILURE, nunca el UNSTABLE del rc 3.
        stage('Cuarentena (CHK-14)') {
            options {
                timeout(time: 20, unit: 'MINUTES')
            }
            steps {
                script {
                    int rc = 0
                    withCredentials([
                        string(credentialsId: 'TEST_USER_STANDARD_USERNAME', variable: 'TEST_USER_STANDARD_USERNAME'),
                        string(credentialsId: 'TEST_USER_STANDARD_PASSWORD', variable: 'TEST_USER_STANDARD_PASSWORD'),
                        string(credentialsId: 'TEST_LOGIN_CASES_LOCKED_USER_USERNAME', variable: 'TEST_LOGIN_CASES_LOCKED_USER_USERNAME'),
                        string(credentialsId: 'TEST_LOGIN_CASES_LOCKED_USER_PASSWORD', variable: 'TEST_LOGIN_CASES_LOCKED_USER_PASSWORD'),
                        string(credentialsId: 'TEST_LOGIN_CASES_INVALID_PASSWORD_USERNAME', variable: 'TEST_LOGIN_CASES_INVALID_PASSWORD_USERNAME'),
                        string(credentialsId: 'TEST_LOGIN_CASES_INVALID_PASSWORD_PASSWORD', variable: 'TEST_LOGIN_CASES_INVALID_PASSWORD_PASSWORD')
                    ]) {
                        rc = sh(returnStatus: true, script: '''#!/usr/bin/env bash
set -euo pipefail
rm -rf quarantine-reports quarantine.log
mkdir -p quarantine-reports
rc=0
git grep -qE '(^|[[:space:]])@quarantine([[:space:]]|$)' -- src/test/resources/features || rc=$?
case "$rc" in
  0) ;;
  1) echo "Sin escenarios con @quarantine: no hay nada que ejecutar."; exit 0 ;;
  *) echo "git grep terminó con $rc" >&2; exit 2 ;;
esac
bash scripts/check-required-secrets.sh
# rc de Maven en la misma orden (PIPESTATUS, por el tee).
set +e
./mvnw -B -ntp clean test -Dtest=RunnerTest -Dheadless=true -Dcucumber.filter.tags="@quarantine" 2>&1 | tee quarantine.log
st=("${PIPESTATUS[@]}")
set -e
mvn_rc="${st[0]}"
if [ "${st[1]}" -ne 0 ]; then
  echo "tee terminó con ${st[1]}: el log de Maven está incompleto" >&2
  exit 1
fi
cp -R target/surefire-reports target/allure-results target/cucumber-report.html quarantine-reports/ 2>/dev/null || true
eval_rc=0
bash scripts/evaluate-quarantine-run.sh "$mvn_rc" quarantine.log || eval_rc=$?
override_rc=0
bash scripts/check-no-expected-override.sh quarantine.log || override_rc=$?
if [ "$eval_rc" -ne 0 ] && [ "$eval_rc" -ne 3 ]; then
  exit "$eval_rc"
fi
if [ "$override_rc" -ne 0 ]; then
  exit "$override_rc"
fi
exit "$eval_rc"
''')
                    }
                    if (rc == 3) {
                        catchError(buildResult: 'SUCCESS', stageResult: 'UNSTABLE') {
                            error('Cuarentena (CHK-14): aviso (un defecto-sut pasa o un inestable termina con error); ver el log de la etapa y docs/quarantine.md')
                        }
                    } else if (rc != 0) {
                        error("Cuarentena (CHK-14): la ejecución no midió la cuarentena o el log tiene un esperado sobrescrito por -D (rc ${rc}; ADR-003, R-2); ver el log de la etapa")
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
