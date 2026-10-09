#!/usr/bin/env bash
# devops-gate-hook.sh — Hook PreToolUse (matcher: Bash) de Claude Code.
# Bloquea cualquier `git push` que no cuente con una aprobación VIGENTE del agente devops-engineer
# (o devops-mobile-engineer). La aprobación vive en .claude/devops-gate.json y solo es válida
# si su `commit` coincide con el HEAD actual y su `verdict` es APROBADO.
#
# Instalación (la hace el skill agent-team-* en la fase de endurecimiento, previa confirmación):
#   1. Copiar este archivo a .claude/hooks/devops-gate-hook.sh y darle permisos: chmod +x
#   2. Registrar el hook en .claude/settings.json (ver templates/settings-hooks-snippet.json)
#   3. Añadir `.claude/devops-gate.json` a .gitignore
#
# Comportamiento:
#   - Comando sin `git push`  → exit 0 (permitido, no interviene)
#   - Sin aprobación / aprobación vieja / veredicto RECHAZADO → exit 2 (bloqueado; el mensaje llega a Claude)
#   - Si no hay `jq` ni `python3` para leer el JSON → avisa y permite (fail-open explícito y visible)
#
# Diseño de la detección — el hook bloquea la EJECUCIÓN de un push, nunca su MENCIÓN:
#   Un comando que solo escribe texto (documentación con `cat <<EOF`, un `echo "…"`, un mensaje de
#   commit) no sube nada y no puede quedar bloqueado; buscar la cadena en cualquier posición del
#   comando produce falsos positivos que paralizan trabajo legítimo. Por eso, antes de decidir, el
#   comando se reduce a su parte ejecutable en tres pasos:
#     1. Se descartan los cuerpos de heredoc — de `<<DELIM` (o `<<-DELIM`, `<<'DELIM'`) hasta su
#        línea de cierre — porque son datos, no comandos. `<<<` es un here-string: solo se descarta
#        el operador, lo que sigue en la línea se sigue analizando.
#     2. Se descartan los tramos entre comillas simples y dobles, por la misma razón.
#     3. Sobre lo que queda se exige que `git` esté en posición de comando (inicio de línea, o tras
#        `;`, `&`, `|`, `(`, `&&`, `||`) y que `push` sea un token completo, admitiendo hasta cuatro
#        tokens intermedios para cubrir `git -C <dir> push`, `git -c clave=valor push` y
#        `git --no-pager push`. Así `git pushd_algo` o `git log --grep=push` no disparan el gate.
#   El error se asume en una sola dirección y de forma consciente: una sintaxis muy exótica podría
#   colarse (se permite de más), nunca al revés. El gate es una barrera contra el olvido, no un
#   aislamiento frente a un adversario.
set -u

INPUT="$(cat)"

extract_command() {
  if command -v jq >/dev/null 2>&1; then
    printf '%s' "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null
  elif command -v python3 >/dev/null 2>&1; then
    printf '%s' "$INPUT" | python3 -c 'import json,sys
try:
    d=json.load(sys.stdin); print(d.get("tool_input",{}).get("command",""))
except Exception:
    print("")' 2>/dev/null
  else
    echo "AVISO devops-gate-hook: ni jq ni python3 disponibles; no se puede inspeccionar el comando. Se permite." >&2
    echo ""
  fi
}

read_json_field() {  # $1 = archivo, $2 = campo
  if command -v jq >/dev/null 2>&1; then
    jq -r ".$2 // empty" "$1" 2>/dev/null
  else
    python3 -c 'import json,sys
try:
    print(json.load(open(sys.argv[1])).get(sys.argv[2],""))
except Exception:
    print("")' "$1" "$2" 2>/dev/null
  fi
}

effective_command() {  # imprime $CMD sin cuerpos de heredoc ni tramos entrecomillados
  local linea resto pre post limpia cierre delim="" salida="" dentro=0
  while IFS= read -r linea || [ -n "$linea" ]; do
    if [ "$dentro" -eq 1 ]; then                 # dentro de un heredoc: todo es dato
      read -r cierre _ <<< "$linea"
      [ "$cierre" = "$delim" ] && dentro=0
      continue
    fi
    resto="$linea"; limpia=""
    while [ -n "$resto" ]; do
      case "$resto" in
        *"<<"*)
          pre="${resto%%<<*}"; post="${resto#*<<}"
          case "$post" in
            "<"*)                                # here-string: se descarta solo el operador
              limpia="$limpia$pre "; resto="${post#<}"; continue ;;
          esac
          read -r delim _ <<< "${post#-}"        # heredoc: el cuerpo empieza en la línea siguiente
          delim="${delim%%[;&|)<>]*}"
          delim="$(printf '%s' "$delim" | tr -d "\"'\\\\")"
          limpia="$limpia$pre"; resto=""
          [ -n "$delim" ] && dentro=1 ;;
        *) limpia="$limpia$resto"; resto="" ;;
      esac
    done
    salida="$salida$limpia
"
  done <<< "$CMD"
  printf '%s' "$salida" | sed "s/'[^']*'//g; s/\"[^\"]*\"//g"
}

CMD="$(extract_command)"
[ -z "$CMD" ] && exit 0

# Solo actúa sobre un `git push` en posición de comando (ver "Diseño de la detección" arriba).
if ! effective_command | grep -Eq '(^|[;&|(]|&&|\|\|)[[:space:]]*git[[:space:]]+([^[:space:];&|]+[[:space:]]+){0,4}push([[:space:]]|$)'; then
  exit 0
fi

ROOT="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
GATE="$ROOT/.claude/devops-gate.json"
HEAD_SHA="$(git -C "$ROOT" rev-parse HEAD 2>/dev/null || echo "")"

if [ ! -f "$GATE" ]; then
  echo "BLOQUEADO por el gate DevOps: no existe $GATE. Invoca al agente devops-engineer para que ejecute el double check del commit $HEAD_SHA y registre el veredicto antes de hacer push." >&2
  exit 2
fi

GATE_SHA="$(read_json_field "$GATE" commit)"
VERDICT="$(read_json_field "$GATE" verdict)"

if [ "$VERDICT" != "APROBADO" ]; then
  echo "BLOQUEADO por el gate DevOps: el veredicto registrado es '${VERDICT:-vacío}'. Resuelve los hallazgos y vuelve a ejecutar al agente devops-engineer." >&2
  exit 2
fi

if [ -z "$HEAD_SHA" ] || [ "$GATE_SHA" != "$HEAD_SHA" ]; then
  echo "BLOQUEADO por el gate DevOps: la aprobación corresponde al commit '${GATE_SHA:-?}' y el HEAD actual es '${HEAD_SHA:-?}'. Hay cambios posteriores al double check; vuelve a ejecutar al agente devops-engineer." >&2
  exit 2
fi

exit 0
