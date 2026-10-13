# Política de seguridad

## Versiones con soporte

Solo la rama `main` recibe correcciones. No hay versiones publicadas ni ramas de mantenimiento.

## Cómo reportar una vulnerabilidad

Usa el **reporte privado de vulnerabilidades** de GitHub: pestaña **Security → Report a vulnerability** de este repositorio. **No abras un issue público** ni un pull request que describa el problema.

Incluye, si puedes:

- qué componente está afectado (por ejemplo, un script de `scripts/`, el workflow de CI, un hook de `.claude/hooks/` o el código de `src/`);
- cómo reproducirlo, con los pasos mínimos;
- el impacto que esperas (fuga de un secreto, ejecución de código en CI, evasión de una comprobación, etc.).

**Nunca adjuntes tu archivo `.env`, credenciales, tokens ni logs que los contengan.** Si un log es necesario, sustituye cualquier valor sensible por `***`.

El mantenedor revisará el reporte y responderá por el mismo canal privado.

## Alcance

**Dentro del alcance:**

- el código del framework (`src/`), los scripts de comprobación (`scripts/`) y sus autopruebas;
- los workflows de GitHub Actions (`.github/workflows/`) y el `Jenkinsfile`, en especial cualquier forma de exponer secrets o de ejecutar código no confiable;
- la configuración de los agentes (`.claude/`): hooks, permisos y reglas que una inyección pudiera evadir.

**Fuera del alcance:**

- [SauceDemo](https://www.saucedemo.com), el sistema bajo prueba: es una aplicación de demostración de terceros. Sus defectos se reportan a su mantenedor, no aquí.
- Las credenciales de práctica de SauceDemo: son públicas y las publica el propio sitio. Aun así, el proyecto las trata como secretas (viven en `.env` o en GitHub Secrets) por buena práctica.
- Los defectos funcionales del SUT que ya están registrados en la cuarentena reglada (`docs/quarantine.md`).

## Medidas que ya aplica el proyecto

- Ningún secreto en el repositorio: credenciales en `.env` (ignorado) o en GitHub Secrets; CHK-06 busca tokens y llaves versionados.
- CI con permisos mínimos (`contents: read`), sin `pull_request_target`, y los pull requests de forks no reciben secrets.
- Los valores esperados y las URL no aceptan variables de entorno (ADR-003), y CHK-19 hace fallar un job si un valor esperado llega por `-D`.
- Hooks que bloquean `git push` sin el gate de DevOps y cualquier escritura por Bash en la configuración de los agentes y en los workflows (`.claude/rules/02-agent-permissions.md`).
