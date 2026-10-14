# MEMORY.md — spec-driven-selenium-cucumber

Memoria del proyecto entre sesiones. Máximo ~50 líneas: resume o elimina lo que ya no aporte.

## Estado actual
- Repositorio **público** desde el 2026-10-13. `main` protegida (ruleset `proteger-main`): solo por PR con los 5 checks en verde, commits firmados y merge commit. PR #1 (`9416b5d`) y PR #2 (`c47648c`) integrados con CI en verde (usuario).
- Suite 224 en verde (`not @quarantine`, 1 omitido = AC-COMPRA-09): 21 E2E (22 AC) + 8 de contrato del transporte + 195 unitarias; PIT 164/164.
- Specs `login.md` y `compra.md` aprobadas, con todos sus AC verificables cubiertos y CHK-10 demostrado. AC-COMPRA-09 en cuarentena `defecto-sut` (revisión 2026-12-31).
- `Navegador`: un solo clic y una sola escritura nativos, sin respaldo JS; `ClicNativoUnico` falla cerrado; dos scripts de lista cerrada; URL solo con el host (`describeHost`, PI-09).
- Chrome (ADR-002 D8): preferencia sin aviso de contraseñas filtradas (clics perdidos) y `--disable-features=NetworkTimeServiceQuerying` (`ERR_CERT_VERIFIER_CHANGED`); `--disable-component-update` se mantiene.
- ADR-001…004 aceptados, implementados y verificados. CHK-01…20 activas (CHK-17: 42 comprobaciones, 517 casos; CHK-18 awk; CHK-19 esperados y URL por job; CHK-20 contrato ejecutado).
- Hooks: gate DevOps y protección de `.claude/**`, `CLAUDE.md`, `MEMORY.md`, `AGENTS.md` y `.github/**` frente a Bash.
- CI: 6 jobs; acciones por SHA, imágenes por digest, wrapper con checksum, `SE_AVOID_STATS`; PR de forks sin E2E; artefactos 14 días sin logs de Maven. Jenkins verificado en real (builds #1 y #3 SUCCESS; #2 por el error de Chrome ya corregido).
- Documentación: README (contexto, capas, cadena de calidad, Jenkins A/B, lámina de estructura), AGENTS.md, CONTRIBUTING.md, SECURITY.md y plantillas; lienzo de diseño "Arquitectura por capas" (privado).

## Decisiones (y por qué)
- El coordinador es la sesión principal, porque un subagente no puede delegar en otros.
- PIT solo sobre la lógica pura; E2E con control negativo (`-D…`); el transporte con pruebas de contrato contra páginas locales.
- El verifier no tiene `memory`: activarla le agrega `Write`/`Edit` y rompe su independencia.
- Solo el usuario aprueba specs (SDD-09) y cambia `.claude/**`, `CLAUDE.md`, `AGENTS.md`; los ADR los aprueba el coordinador.
- Sin respaldo JS ni reintentos: ocultaron causas reales (verde falso).
- Cada tanda va a una rama `tanda/<tema>` con el gate; el usuario fusiona por PR con merge commit (los ADR citan hashes).
- Mantener `MEMORY.md`, `AGENTS.md` y `README.md` al día en cada tanda, sin faltar nada (el usuario).

## Aprendizajes y errores a evitar
- Commits sin `Co-Authored-By` ni marcas de IA; firmados con SSH (`%G?` = `G`). Gate JSON y push en comandos separados.
- Sin `Grep`/`Glob`: `git grep`/`git ls-files`. Nunca `--no-index`/`--untracked` en la raíz: abre `.env`.
- El runner usa gawk y Ubuntu mawk: probar con `run-with-each-awk.sh` (gawk instalado en local).
- Los workflows y `.claude/` se editan solo con `Edit`/`Write`; el hook bloquea Bash (y `python3 -c` sobre esas rutas).
- Los fallos de Chrome "por carga" tenían causas concretas (aviso de contraseñas; consulta de hora de red): medir con NetLog antes de culpar al entorno.
- `--disable-features`: uno solo propio; ChromeDriver lo une con los suyos. Si Chrome renombra una feature, se ignora en silencio: volver a medir.
- Un "no pasa X" por ausencia da verde falso: exigir prueba positiva. AC-COMPRA-09: revisar el log (pista de D8) antes de sacarlo de cuarentena.
- Selenium imprime la URL completa en sus errores: nombrar URL solo con `describeHost`.
- PIT no muta literales, regex, asignaciones ni `List.add`: control negativo manual. Exigir `mutations.xml`.
- No correr dos Maven a la vez. Firefox local (snap) necesita `-Dwebdriver.gecko.driver=/snap/bin/geckodriver`. No existe la CLI `gh`.

## Próximos pasos
1. Mantenimiento: al subir Selenium o Chrome, renovar los 3 digests, los SHA de las acciones y volver a medir D8 con NetLog (~100 sesiones).
2. Al cambiar la estructura del repositorio, regenerar la lámina `docs/assets/estructura-del-proyecto.png` desde el lienzo de diseño.
3. Revisar AC-COMPRA-09 antes del 2026-12-31 (CHK-14 falla si vence).
4. Riesgo aceptado: aviso de CDP de Selenium 4.45 con Chrome 155 (inocuo).
