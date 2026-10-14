#!/usr/bin/env bash
# CHK-19 (ADR-003, R-2 y D6): un job E2E falla si su log de Maven contiene el
# aviso de D3, o si un destino de red no viene de la fuente que declara el job.
#
# Uso: bash scripts/check-no-expected-override.sh [--destino-d <clave>=<host>]... <log de Maven>
#
# R-2. ConfigReader registra un WARN cuando una clave de esperado (*.expected*)
# viene de una propiedad del sistema (-D), una vez por clave y por JVM (D3):
#   La clave de esperado '<clave>' viene de una propiedad del sistema (-D): ...
# Solo es válido en el control negativo (CHK-10), que se ejecuta a mano. En CI
# significa que un esperado llegó por la línea de comandos o por el entorno
# (MAVEN_ARGS, JAVA_TOOL_OPTIONS, JDK_JAVA_OPTIONS), y la suite podría estar en
# verde comparando contra un valor manipulado. Se busca solo la parte ASCII del
# mensaje (sin "válido"), en cualquier parte de la línea: falla cerrado.
#
# D6. ConfigReader registra en INFO, una vez por clave y por JVM, la fuente y
# solo el host de cada destino de red (base.url, remote.url):
#   Destino de red '<clave>': fuente=<sistema|entorno|archivo|ausente>, host=<host>
# El control exige:
#   - validez: cada línea con la marca "Destino de red '" (exacta, con la
#     comilla, en cualquier parte de la línea) cumple LINEA desde la marca hasta
#     el final, sin un \r final; si no, es violación y no se repite su contenido;
#   - fuente esperada: sin bandera, fuente=archivo o ausente; con
#     --destino-d <clave>=<host>, esa clave llega con fuente=sistema y
#     exactamente ese host. Se evalúan todas las líneas de cada clave;
#   - presencia: al menos una línea válida de base.url y otra de remote.url.
#     Un nivel de log, un logFile o la salida del fork redirigida las quitan
#     (y con ellas el aviso de D3): sin ellas no se puede evaluar (2).
# Las banderas van antes del log; cada clave, una sola vez; la clave cumple
# [A-Za-z0-9._-]{1,200} y el host HOST (sin "(ninguno)" ni "(invalido)").
#
# El log tiene que probar que la suite E2E corrió: al menos una línea de
# Surefire "Tests run: N, … -- in com.demo.runners.RunnerTest" con N >= 1.
#
# Salida, en este orden:
#   1  violaciones: el aviso de D3 (con la clave, nunca un valor; una clave
#      fuera de [A-Za-z0-9._-]{1,200} se informa como "(clave no válida)") y
#      las de D6 (línea no válida, o fuente u host distintos de lo esperado):
#      "<log>:<línea>: R-2: …" y "<log>:<línea>: D6: …".
#   2  no se puede evaluar (falla cerrado): uso, log ausente, que no es un
#      archivo regular, ilegible o vacío, error de lectura (grep con rc >= 2 o
#      con texto en stderr), sin la línea "Tests run" de RunnerTest, y después
#      sin la línea de destino de base.url o de remote.url.
#   0  nada de lo anterior.
#
# El texto del log es dato (Regla 03): solo se compara y se citan la clave, la
# fuente y el host validados; nunca se evalúa ni se usa para construir un
# comando (PI-04). Solo bash, coreutils, grep y sed (sin awk).
set -euo pipefail
export LC_ALL=C

me="check-no-expected-override"
err() { echo "$me: $*" >&2; exit 2; }
uso="uso: bash scripts/check-no-expected-override.sh [--destino-d <clave>=<host>]... <log de Maven>"

CLAVE_RE='[A-Za-z0-9._-]{1,200}'
HOST_RE='[a-z0-9.-]{1,253}(:[0-9]{1,5})?'

# Banderas --destino-d <clave>=<host>, antes del log.
declare -A destino_d=()
while [ "$#" -gt 0 ]; do
  case "$1" in
    --destino-d)
      [ "$#" -ge 2 ] || err "$uso"
      [[ "$2" =~ ^($CLAVE_RE)=($HOST_RE)$ ]] || err "$uso"
      d_clave="${BASH_REMATCH[1]}"
      d_host="${BASH_REMATCH[2]}"
      [ -z "${destino_d[$d_clave]+x}" ] || err "$uso"
      destino_d[$d_clave]="$d_host"
      shift 2
      ;;
    --*) err "$uso" ;;
    *) break ;;
  esac
done
[ "$#" -eq 1 ] || err "$uso"
log="$1"
[ -e "$log" ] || err "no existe el log '$log'"
[ -f "$log" ] || err "'$log' no es un archivo regular"
[ -r "$log" ] || err "no se puede leer el log '$log'"
[ -s "$log" ] || err "el log '$log' está vacío: no prueba que la suite corriera"

errf="$(mktemp)"
trap 'rm -f "$errf"' EXIT

# grep_log <variable> <opciones y patrón…>: deja la salida en <variable>.
# 0 = coincide, 1 = no coincide; >= 2 o stderr = error de lectura (2).
# Cada búsqueda pasa -a: un byte NUL en el log no lo convierte en "binario"
# (que ocultaría líneas).
grep_rc=0
grep_log() {
  local __var="$1" __out
  shift
  grep_rc=0
  __out="$(grep "$@" -- "$log" 2>"$errf")" || grep_rc=$?
  if [ "$grep_rc" -ge 2 ] || [ -s "$errf" ]; then
    cat "$errf" >&2
    err "grep terminó con $grep_rc al leer '$log'"
  fi
  printf -v "$__var" '%s' "$__out"
}

viol=0

# R-2: el aviso de D3.
marca="La clave de esperado '[^']*' viene de una propiedad del sistema \\(-D\\)"
hits=""
grep_log hits -a -n -E "$marca"
if [ "$grep_rc" -eq 0 ]; then
  while IFS= read -r hit; do
    num="${hit%%:*}"
    clave="$(printf '%s\n' "${hit#*:}" \
      | sed -n "s/.*La clave de esperado '\\([^']*\\)' viene de una propiedad del sistema (-D).*/\\1/p")"
    if ! [[ "$clave" =~ ^$CLAVE_RE$ ]]; then
      clave="(clave no válida)"
    fi
    echo "$log:$num: R-2: la clave de esperado '$clave' se sobrescribió con -D (ADR-003, D3): solo es válido en el control negativo (CHK-10), nunca en CI"
    viol=1
  done <<< "$hits"
fi

# D6: validez y fuente esperada de cada línea de destino.
marca_d6="Destino de red '"
LINEA_RE="^Destino de red '($CLAVE_RE)': fuente=(sistema|entorno|archivo|ausente), host=($HOST_RE|\\(ninguno\\)|\\(invalido\\))\$"
hay_base=0
hay_remote=0
destinos=""
grep_log destinos -a -n -F "$marca_d6"
if [ "$grep_rc" -eq 0 ]; then
  while IFS= read -r hit; do
    num="${hit%%:*}"
    linea="${hit#*:}"
    linea="${linea%$'\r'}"
    resto="$marca_d6${linea#*"$marca_d6"}"
    if ! [[ "$resto" =~ $LINEA_RE ]]; then
      echo "$log:$num: D6: línea de destino de red no válida (ADR-003, D6)"
      viol=1
      continue
    fi
    clave="${BASH_REMATCH[1]}"
    fuente="${BASH_REMATCH[2]}"
    host="${BASH_REMATCH[3]}"
    case "$clave" in
      base.url) hay_base=1 ;;
      remote.url) hay_remote=1 ;;
    esac
    if [ -n "${destino_d[$clave]+x}" ]; then
      esperado="fuente=sistema y host=${destino_d[$clave]}"
      if [ "$fuente" = sistema ] && [ "$host" = "${destino_d[$clave]}" ]; then
        continue
      fi
    else
      esperado="fuente=archivo o ausente"
      case "$fuente" in
        archivo | ausente) continue ;;
      esac
    fi
    echo "$log:$num: D6: el destino de red '$clave' tiene fuente=$fuente y host=$host; en este job se espera $esperado (ADR-003, D6)"
    viol=1
  done <<< "$destinos"
fi

if [ "$viol" -ne 0 ]; then
  exit 1
fi

corrida=""
grep_log corrida -a -c -E \
  'Tests run: 0*[1-9][0-9]*, Failures: [0-9]+, Errors: [0-9]+, Skipped: [0-9]+, Time elapsed: .* -- in com\.demo\.runners\.RunnerTest([^A-Za-z0-9_$.]|$)'
if [ "$grep_rc" -ne 0 ]; then
  err "el log '$log' no tiene la línea \"Tests run: N, … -- in com.demo.runners.RunnerTest\" con N >= 1: la suite E2E no corrió o el log está incompleto"
fi

# D6: presencia, una línea por clave que falta (primero base.url).
falta=0
if [ "$hay_base" -eq 0 ]; then
  echo "$me: el log '$log' no registra el destino de red 'base.url' (ADR-003, D6): no prueba adónde fue la suite" >&2
  falta=1
fi
if [ "$hay_remote" -eq 0 ]; then
  echo "$me: el log '$log' no registra el destino de red 'remote.url' (ADR-003, D6): no prueba adónde fue la suite" >&2
  falta=1
fi
if [ "$falta" -ne 0 ]; then
  exit 2
fi

echo "$me: ok: sin esperados sobrescritos por -D y con los destinos de red esperados en '$log' (ADR-003, R-2 y D6)"
exit 0
