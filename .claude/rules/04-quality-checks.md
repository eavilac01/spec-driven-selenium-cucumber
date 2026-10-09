# Regla 04 — Catálogo de comprobaciones (CHK)

Comprobaciones deterministas que los agentes citan por ID. Una CHK en rojo es un **rechazo**, no una sugerencia.

| ID | Qué verifica | Pasa si | Ejecuta |
|---|---|---|---|
| CHK-01 | Sin `Thread.sleep` ni esperas implícitas | Sin salida | engineer, verifier, devops |
| CHK-02 | Sin reintentos automáticos | Sin salida | verifier, devops |
| CHK-03 | Steps y acciones sin Selenium | Sin salida | engineer, verifier |
| CHK-04 | Features sin vocabulario de interfaz | Sin salida (el diseñador lo comprueba con `Grep`) | designer, verifier |
| CHK-05 | Higiene del repositorio | Sin salida | devops |
| CHK-06 | Sin tokens ni llaves versionadas | Sin salida, salvo coincidencias que sean la definición de un patrón | devops |
| CHK-07 | Compilación | Código de salida 0 | engineer, devops |
| CHK-08 | Suite completa | `BUILD SUCCESS` (devops la corre **2 veces** con el mismo `Tests run`) | engineer, devops |
| CHK-09 | Escenario independiente | Verde solo y dentro de la suite | engineer, verifier |
| CHK-10 | Control negativo | **Falla** con `AssertionFailedError` en el `Then` | verifier |
| CHK-11 | Mutación | Puntaje ≥ 80 % en las clases tocadas | verifier, devops |
| CHK-12 | Trazabilidad SDD | Cada escenario tiene `@AC-` y `@tec-`, y cada feature tiene `Spec:` | designer, devops |
| CHK-13 | Pipelines válidos | Sin error | devops |
| CHK-14 | Cuarentena reglada | Cada `@quarantine` tiene su fila en `docs/quarantine.md` con dueño y fecha no vencida | devops |

## Comandos (copiar tal cual)

```bash
# CHK-01
git grep -nP "Thread\.sleep|TimeUnit\.[A-Z]+\.sleep|implicitlyWait\((?!Duration\.ZERO)" -- src
# CHK-02
git grep -nE "rerunFailingTestsCount|rerun:" -- pom.xml src .github Jenkinsfile
# CHK-03
git grep -n "import org.openqa.selenium" -- src/test/java/com/demo/steps src/test/java/com/demo/actions
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
# CHK-11
./mvnw -B -ntp test-compile org.pitest:pitest-maven:mutationCoverage
# CHK-12
bash scripts/check-traceability.sh
# CHK-13
python3 -c "import yaml,sys;[yaml.safe_load(open(f)) for f in sys.argv[1:]]" .github/workflows/*.yml
```

**Estado actual:** CHK-11 (PIT) y CHK-12 (script) aún no están configuradas; crearlas es tarea de `devops-engineer`. Mientras tanto se reportan como `n/a` con un hallazgo P1.

La cobertura de líneas **no** es una CHK: mide qué código se ejecutó, no qué se verificó.
