#!/usr/bin/env bash
# protect-config-hook.sh — Hook PreToolUse (matcher: Bash) de Claude Code.
#
# Cierra el hueco de `ask`: las reglas `ask` de settings.json solo controlan las herramientas
# Edit/Write, así que un comando Bash podía modificar la configuración de los agentes sin pedir
# confirmación. Este hook bloquea los comandos Bash que ESCRIBEN en rutas protegidas:
#   .claude/**   CLAUDE.md   MEMORY.md
# Excepción: .claude/devops-gate.json, que el agente devops-engineer escribe por diseño.
#
# Leer está permitido (cat, grep, git grep, git diff, wc, sed -n, python script.py ruta…).
# Escribir se detecta, dentro de cada segmento del comando (separado por | ; &), así:
#   - redirección (> o >>) cuyo destino es una ruta protegida;
#   - tee, sed -i/--in-place, rm, mv, cp, ln, touch, truncate, chmod, chown, install, rsync,
#     dd con of=, y git checkout/restore/rm/mv/clean/apply/stash, sobre una ruta protegida;
#   - intérpretes con código en línea (python -c/-, perl -e, ruby -e, node -e, bash/sh -c)
#     cuando el comando completo menciona una ruta protegida (el código puede escribir en ella).
#
# Criterio de error, igual que el gate de push: es una barrera contra el olvido y contra
# instrucciones inyectadas, no un aislamiento frente a un adversario. Ante la duda bloquea, y el
# camino legítimo para cambiar la configuración son las herramientas Edit/Write, que pasan por
# la confirmación del usuario.
#
# Pruebas: python3 -I .claude/hooks/tests/test_protect_hook.py .claude/hooks/protect-config-hook.sh
# Salida: exit 0 permite; exit 2 bloquea (el mensaje de stderr llega a Claude).
set -u

INPUT="$(cat)"

extract_command() {
  if command -v jq >/dev/null 2>&1; then
    printf '%s' "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null
  elif command -v python3 >/dev/null 2>&1; then
    printf '%s' "$INPUT" | python3 -I -c 'import json,sys
try:
    print(json.load(sys.stdin).get("tool_input",{}).get("command",""))
except Exception:
    print("")' 2>/dev/null
  else
    echo "AVISO protect-config-hook: ni jq ni python3 disponibles; no se puede inspeccionar el comando. Se permite." >&2
    echo ""
  fi
}

CMD="$(extract_command)"
[ -z "$CMD" ] && exit 0

# La excepción se elimina antes de analizar: escribir el veredicto del gate es legítimo.
ANALYSIS="${CMD//.claude\/devops-gate.json/__GATE_FILE__}"

# Ruta protegida: un segmento ".claude" de ruta, o los archivos CLAUDE.md / MEMORY.md.
PROT='(\.claude([/"'"'"'[:space:]]|$)|CLAUDE\.md|MEMORY\.md)'

# Sin ninguna mención a una ruta protegida no hay nada que analizar.
printf '%s' "$ANALYSIS" | grep -Eq "$PROT" || exit 0

SEG='[^|;&]*'   # resto del segmento actual del comando
WRITERS='(tee|sed[[:space:]]+(-[a-zA-Z]*i|--in-place)|rm|mv|cp|ln|touch|truncate|chmod|chown|install|rsync|dd[[:space:]]+[^|;&]*of=)'
GIT_WRITERS='git[[:space:]]+(checkout|restore|rm|mv|clean|apply|stash)'
INLINE='(python3?|perl|ruby|node)[[:space:]]+(-[a-zA-Z]*[ce]|-)([[:space:]]|$)|(bash|sh|zsh)[[:space:]]+-c'

reason=""
if printf '%s' "$ANALYSIS" | grep -Eq ">>?[[:space:]]*[\"']?[^[:space:]|;&]*$PROT"; then
  reason="redirección (> o >>) hacia una ruta protegida"
elif printf '%s' "$ANALYSIS" | grep -Eq "(^|[^[:alnum:]_.-])$WRITERS([[:space:]]$SEG)$PROT"; then
  reason="comando que modifica archivos sobre una ruta protegida"
elif printf '%s' "$ANALYSIS" | grep -Eq "(^|[^[:alnum:]_.-])$GIT_WRITERS$SEG$PROT"; then
  reason="git que reescribe archivos de una ruta protegida"
elif printf '%s' "$ANALYSIS" | grep -Eq "(^|[^[:alnum:]_.-])($INLINE)"; then
  reason="intérprete con código en línea en un comando que menciona una ruta protegida"
fi

if [ -n "$reason" ]; then
  echo "BLOQUEADO por protect-config-hook: $reason (.claude/**, CLAUDE.md o MEMORY.md). La configuración de los agentes solo se modifica con las herramientas Edit/Write, que piden confirmación al usuario (Regla 02, P-01; Regla 03, PI-07). Si solo necesitas leer, usa un comando de lectura." >&2
  exit 2
fi
exit 0
