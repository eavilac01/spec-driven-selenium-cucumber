#!/usr/bin/env bash
# Verifica que las variables de .env.example existan y no estén vacías en el
# entorno del paso de CI (GitHub Actions o Jenkins con withCredentials).
#
# Uso: bash scripts/check-required-secrets.sh [ruta-a-.env.example]
#
# Nunca imprime valores: solo los NOMBRES que faltan (P-02, PI-09).
# Sale con 1 si falta alguno y con 2 si .env.example no existe o no declara
# ninguna variable (falla cerrado: una lista vacía no puede pasar en verde).
# Existe como script para que GitHub Actions y Jenkins comprueben lo mismo.
set -euo pipefail
export LC_ALL=C

example="${1:-.env.example}"
if [ ! -f "$example" ]; then
  echo "check-required-secrets: no existe '$example'" >&2
  exit 2
fi

names=$(grep -E '^[A-Z_][A-Z0-9_]*=' "$example" | cut -d= -f1 || true)
if [ -z "$names" ]; then
  echo "check-required-secrets: '$example' no declara ninguna variable" >&2
  exit 2
fi

missing=0
for name in $names; do
  if [ -z "${!name:-}" ]; then
    if [ "${GITHUB_ACTIONS:-}" = "true" ]; then
      echo "::error title=Secret faltante::Configura '$name' en Settings > Secrets and variables > Actions"
    else
      echo "Secret faltante: '$name' (credencial de tipo Secret text con el mismo ID)" >&2
    fi
    missing=1
  fi
done

if [ "$missing" -eq 0 ]; then
  echo "check-required-secrets: $(printf '%s\n' $names | wc -l) variables presentes"
fi
exit "$missing"
