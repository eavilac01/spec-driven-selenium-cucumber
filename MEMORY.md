# MEMORY.md — spec-driven-selenium-cucumber

Memoria del proyecto entre sesiones. Máximo ~50 líneas: resume o elimina lo que ya no aporte.

## Estado actual
- Suite 222 en verde (local, `not @quarantine`, 1 omitido = AC-COMPRA-09): 21 E2E (22 AC) + 8 de contrato del transporte + unitarias; PIT 164/164. PR #1 (`tanda/cierre-pendientes`) integrado con merge commit `9416b5d`; su CI en verde (usuario, 2026-10-13).
- Specs `login.md` y `compra.md` aprobadas, con todos sus AC verificables cubiertos y CHK-10 demostrado. AC-COMPRA-09 en cuarentena `defecto-sut`.
- `Navegador`: un solo clic y una sola escritura nativos por acción, sin respaldo JS; `ClicNativoUnico` (src/main) cuenta el clic solo si `click()` retorna y falla cerrado si lanza (ADR-004); dos scripts de lista cerrada; errores y logs solo con el host (`describeHost`, PI-09).
- Causa de los clics perdidos: el aviso de contraseñas filtradas de Chrome (headless); `BrowserSettings.chromePreferences()` lo desactiva (D8). La pista de D8 se observa sin red en las pruebas de contrato (CT-04/05).
- ADR-001…004 aceptados e implementados. CHK-17: 42 comprobaciones, autoprueba de 517 casos. CHK-19: esperados y fuente de `base.url`/`remote.url` por job. CHK-20: las pruebas de contrato se ejecutaron.
- CHK-01…20 activas. Hooks: gate DevOps y protección de `.claude/**`, `CLAUDE.md`, `MEMORY.md`, `AGENTS.md` y `.github/**` frente a Bash.
- CI: 6 jobs; acciones por SHA, imágenes por digest, wrapper con checksum, `SE_AVOID_STATS`; PR de forks sin E2E (`fork-pr-notice`); artefactos de 14 días sin logs de Maven.
- Jenkins verificado en real (build #1 SUCCESS, Docker local); el README documenta la opción A (servidor) y B (Docker).
- Listo para publicar: auditoría de 87 commits sin secretos; SECURITY.md, CONTRIBUTING.md y plantillas; ruleset `proteger-main` creado (se aplica al hacerlo público); secrets de Dependabot cargados.
- Documentación: README con vistas de contexto, capas y cadena de calidad (Mermaid) y la lámina `docs/assets/estructura-del-proyecto.png` (del lienzo de diseño "Arquitectura por capas").

## Decisiones (y por qué)
- El coordinador es la sesión principal, porque un subagente no puede delegar en otros.
- PIT solo sobre la lógica pura; los E2E se validan con control negativo (`-D…`); el transporte con pruebas de contrato contra páginas locales (ADR-004).
- El verifier no tiene `memory`: activarla le agrega `Write`/`Edit` y rompe su independencia.
- Solo el usuario aprueba specs (SDD-09) y cambia `.claude/**`, `CLAUDE.md`, `AGENTS.md`; los ADR los aprueba el coordinador.
- Sin respaldo JS: un clic por JS se salta el hit-testing y ocultó la causa real (verde falso).
- `main` solo recibe cambios por PR con los 5 checks en verde y merge commit (los ADR citan hashes): sin push directo, ni del autor.
- Mantener `MEMORY.md`, `AGENTS.md` y `README.md` al día en cada tanda, sin faltar nada (el usuario).

## Aprendizajes y errores a evitar
- Commits sin `Co-Authored-By` ni marcas de IA; firmados con SSH (`%G?` = `G`). Gate JSON y push en comandos separados.
- Sin `Grep`/`Glob`: `git grep`/`git ls-files`. Nunca `--no-index`/`--untracked` en la raíz: abre `.env`.
- El runner usa gawk y Ubuntu mawk: probar con `run-with-each-awk.sh` (gawk instalado en local).
- Los workflows y `.claude/` se editan solo con `Edit`/`Write`; el hook bloquea Bash (y `python3 -c` sobre esas rutas).
- "Con carga Chrome pierde clics" era falso: dependía de si el servicio de Google respondía 200 o 429.
- Un "no pasa X" por ausencia da verde falso: exigir prueba positiva. AC-COMPRA-09: un clic perdido también "no avanza"; antes de sacarlo de cuarentena, revisar el log (pista de D8).
- Selenium imprime la URL completa en sus errores: nombrar URL solo con `describeHost`.
- PIT no muta literales, regex ni asignaciones: control negativo manual. Sin `target/classes` da `BUILD SUCCESS` sin mutar: exigir `mutations.xml`.
- `net::ERR_CERT_VERIFIER_CHANGED` (~1 % de sesiones) no era carga ni NSS: la consulta de hora de red de Chrome reconstruye el verificador y corta la primera navegación. Arreglo: `--disable-features=NetworkTimeServiceQuerying` (único `--disable-features` propio, que ChromeDriver une con los suyos; ADR-002 D8, parte 7); 0 de 2.000. Si reaparece, medir con NetLog, nunca reintentos.
- No correr dos Maven a la vez. Firefox local (snap) necesita `-Dwebdriver.gecko.driver=/snap/bin/geckodriver`. No existe la CLI `gh`.

## Próximos pasos
1. PR del arreglo de `ERR_CERT_VERIFIER_CHANGED` (`BrowserSettings`, ADR-002 D8 parte 7) con los 5 checks en verde; merge commit.
2. Usuario: aplicar los ajustes de GitHub (Actions, Pull Requests, Signing key), hacerlo público y comprobar que el ruleset `proteger-main` deja de mostrar el aviso.
3. P2: renovar los 3 digests de Selenium, los SHA de las acciones y la lámina de estructura cuando cambien las versiones o el repositorio.
4. Riesgo aceptado: el aviso de CDP de Selenium 4.45 con Chrome 155 (inocuo; desaparece al subir Selenium).
