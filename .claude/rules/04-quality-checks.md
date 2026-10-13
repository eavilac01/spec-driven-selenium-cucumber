# Regla 04 — Catálogo de comprobaciones (CHK)

Comprobaciones deterministas que los agentes citan por ID. Una CHK en rojo es un **rechazo**, no una sugerencia.

| ID | Qué verifica | Pasa si | Ejecuta |
|---|---|---|---|
| CHK-01 | Sin `Thread.sleep` ni esperas implícitas | Sin salida | engineer, verifier, devops |
| CHK-02 | Sin reintentos automáticos | Sin salida | verifier, devops |
| CHK-03 | Steps y acciones sin Selenium | Sin salida | engineer, verifier |
| CHK-04 | Features sin vocabulario de interfaz | Sin salida | designer, verifier |
| CHK-05 | Higiene del repositorio | Sin salida | devops |
| CHK-06 | Sin tokens ni llaves versionadas | Sin salida, salvo coincidencias que sean la definición de un patrón | devops |
| CHK-07 | Compilación | Código de salida 0 | engineer, devops |
| CHK-08 | Suite completa | `BUILD SUCCESS` (devops la corre **2 veces** con el mismo `Tests run`) | engineer, devops |
| CHK-09 | Escenario independiente | Verde solo y dentro de la suite | engineer, verifier |
| CHK-10 | Control negativo | **Falla** con `AssertionFailedError` en el `Then` | verifier |
| CHK-11 | Mutación (alcance del ADR-001: todo `src/main/java`) | Puntaje ≥ 80 % en la ejecución y la guarda en 0 (`mutations.xml` presente, sin `Skipping project`); cada mutante sobreviviente de las clases tocadas, justificado | verifier, devops |
| CHK-12 | Trazabilidad SDD: `Spec:` hacia una spec `aprobada`, `@AC-` y `@tec-` en cada escenario, cada `@AC-` existe en la spec y cada AC verificable tiene escenario | Exit 0; con exit 1 imprime `archivo:línea: motivo` | designer, devops |
| CHK-13 | Pipelines válidos | Sin error | devops |
| CHK-14 | Cuarentena reglada, con dos tipos | Cada `@quarantine` tiene su fila en `docs/quarantine.md` con su tipo: `inestable` (dueño, ingreso, issue, diagnóstico y límite ≤ 14 días, no vencido) o `defecto-sut` (dueño, referencia al defecto en la spec según SDD-08, comportamiento esperado frente a observado y próxima revisión ≤ 90 días, no vencida); una fila por cada `@AC-` en cuarentena (propia o heredada) y ninguna fila sin escenario. Exit 0 en el script y en su autoprueba; con exit 1 imprime `archivo:línea: motivo` | devops |
| CHK-15 | `src/main/java` puro: sin entorno, archivos, Selenium, Cucumber ni JUnit (ADR-001) | Sin salida | engineer, verifier, devops |
| CHK-16 | Pruebas unitarias aisladas: sin Selenium, Cucumber, capas de prueba, entorno ni `.env` real, y solo `*Test.java` en sus directorios (ADR-001) | Sin salida | engineer, verifier |
| CHK-17 | Capas (ADR-002): R1–R6 de D7, incluidas páginas como parámetro en acciones y `ResultadoClic` en miembros expuestos de páginas; las firmas expuestas incluyen anotaciones, cualquier orden de modificadores y `protected`, y en `transport`, `pages` y `actions` no hay interfaces, anotaciones ni records expuestos (D7, *Firmas expuestas*); falla cerrado (directorios de capa, `git grep` con rc ≥ 2 o con stderr) | Exit 0 en el script y en su autoprueba | engineer, verifier, devops |
| CHK-18 | Portabilidad de awk: los scripts no usan nombres ni funciones exclusivos de una implementación (en el runner `awk` es gawk; en Ubuntu de escritorio, mawk), y las autopruebas que ejercitan awk pasan con mawk, gawk y `gawk --posix` | Exit 0 en el control estático, en las dos autopruebas y en la matriz; sin gawk, `--require` falla cerrado con 2 | devops |

## Comandos (copiar tal cual)

```bash
# CHK-01
git grep -nP "Thread\.sleep|TimeUnit\.[A-Z]+\.sleep|implicitlyWait\((?!Duration\.ZERO)" -- src
# CHK-02
git grep -nE "rerunFailingTestsCount|rerun:" -- pom.xml src .github Jenkinsfile
# CHK-03 (detecta también `import static` y nombres calificados)
git grep -nE 'org\.openqa' -- src/test/java/com/demo/steps src/test/java/com/demo/actions
# CHK-04
git grep -niE "\b(clic|click|botón|campo|input|xpath|css|selector)\b" -- src/test/resources/features
# CHK-05
git ls-files | grep -E '^(target|allure-results|\.idea)/|(^|/)\.env$'
# CHK-06
git grep -nE "ghp_[A-Za-z0-9]{36}|AKIA[0-9A-Z]{16}|BEGIN [A-Z ]*PRIVATE KEY"
# CHK-07
./mvnw -B -ntp -q test-compile
# CHK-08
./mvnw -B -ntp clean test -Dheadless=true -Dcucumber.filter.tags="not @quarantine"
# CHK-09
./mvnw -B -ntp test -Dheadless=true -Dcucumber.filter.tags="@AC-XXX-NN"
# CHK-10 (la clave sale del valor esperado que verifica el Then)
./mvnw -B -ntp test -Dheadless=true -Dcucumber.filter.tags="@AC-XXX-NN" -D<clave.esperada>=__CONTROL_NEGATIVO__
# CHK-11 (con la guarda contra el "Skipping project" de PIT, que da BUILD SUCCESS sin mutar nada)
rm -rf target/pit-reports
bash -c 'set -o pipefail; ./mvnw -B -ntp test-compile org.pitest:pitest-maven:mutationCoverage 2>&1 | tee pit.log' && bash scripts/check-mutation-report.sh pit.log
# CHK-12
bash scripts/check-traceability.sh
# CHK-13
python3 -c "import yaml,sys;[yaml.safe_load(open(f)) for f in sys.argv[1:]]" .github/workflows/*.yml
# CHK-14 (dos comandos; ambos en 0)
bash scripts/tests/check-quarantine-test.sh
bash scripts/check-quarantine.sh
# CHK-15
git grep -nE 'System\.(getenv|getProperty)|java\.nio\.file|java\.io\.File|getResource|org\.openqa|io\.cucumber|org\.junit' -- src/main/java
# CHK-16 (dos comandos; ambos sin salida)
git grep -nE 'org\.openqa|io\.cucumber|com\.demo\.(utils|transport|pages|actions|steps|hooks|runners)|System\.getenv|"\.env"' -- src/test/java/com/demo/config src/test/java/com/demo/data
git ls-files src/test/java/com/demo/config src/test/java/com/demo/data | grep -v 'Test\.java$'
# CHK-15 y CHK-16 juntas, como en CI y Jenkins (exit 0 = sin salida; falla cerrado si git grep da error)
bash scripts/check-unit-purity.sh
# CHK-17 (capas, ADR-002) y su autoprueba (temporal fuera del repo)
bash scripts/check-layers.sh
bash scripts/tests/check-layers-test.sh
# CHK-18 (portabilidad de awk): control estático y autopruebas del control y del runner de la matriz
bash scripts/check-awk-portability.sh
bash scripts/tests/check-awk-portability-test.sh
bash scripts/tests/run-with-each-awk-test.sh
# CHK-18, matriz: las autopruebas que ejercitan awk, con cada implementación (como en CI; requiere gawk instalado)
bash scripts/run-with-each-awk.sh --require mawk --require gawk --require gawk-posix -- bash scripts/tests/check-layers-test.sh
bash scripts/run-with-each-awk.sh --require mawk --require gawk --require gawk-posix -- bash scripts/tests/check-quarantine-test.sh
bash scripts/run-with-each-awk.sh --require mawk --require gawk --require gawk-posix -- bash scripts/tests/evaluate-quarantine-run-test.sh
```

Control negativo de CHK-11 (ADR-001, D6): con menos pruebas, el umbral **debe** fallar (`BUILD FAILURE`).

```bash
./mvnw -B -ntp test-compile org.pitest:pitest-maven:mutationCoverage -Dpit.targetTests='com.demo.data.*Test'
```

**Estado actual:** CHK-12 está activa en `scripts/check-traceability.sh` y corre en GitHub Actions y Jenkins antes de la suite. CHK-11, CHK-15 y CHK-16 están activas (ADR-001): job `mutation` en GitHub Actions y etapa `Mutation (CHK-11)` en Jenkins, sin secrets ni navegador (`90687f4`), con `scripts/check-mutation-report.sh` contra el fallo abierto de PIT. CHK-17 está activa (ADR-002): `scripts/check-layers.sh` y su autoprueba corren en el job `mutation` de GitHub Actions y en la etapa `Capas (CHK-17)` de Jenkins, sin secrets (`f7f7a13`). CHK-14 está activa: `scripts/check-quarantine.sh` y su autoprueba corren en el job `mutation` y en Jenkins; el job `quarantine` ejecuta solo los escenarios en cuarentena sin bloquear el pipeline y avisa si alguno pasa. CHK-18 está activa: el control estático y la matriz corren en el job `mutation` de GitHub Actions, que exige mawk, gawk y `gawk --posix` (`1d3a593` y `34f8528`), y en la etapa `Portabilidad de awk` de Jenkins, con los awk que tenga el agente.

La cobertura de líneas **no** es una CHK: mide qué código se ejecutó, no qué se verificó.
