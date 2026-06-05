#!/usr/bin/env bash
# Restauração do banco a partir de um dump gerado por scripts/backup.sh.
# Uso:  ./scripts/restore.sh backups/receita_AAAAMMDD_HHMMSS.dump
#       ./scripts/restore.sh            (usa o backup mais recente)
set -euo pipefail

cd "$(dirname "$0")/.."

DB_USER="${POSTGRES_USER:-receita}"
DB_NAME="${POSTGRES_DB:-receita_dev}"

FILE="${1:-}"
if [ -z "$FILE" ]; then
  FILE="$(ls -1t backups/receita_*.dump 2>/dev/null | head -n1 || true)"
fi

if [ -z "$FILE" ] || [ ! -f "$FILE" ]; then
  echo "✗ Arquivo de backup não encontrado: '${FILE}'" >&2
  echo "  Informe o caminho ou gere um backup com scripts/backup.sh" >&2
  exit 1
fi

echo "⚠️  Isto vai SOBRESCREVER os dados de '${DB_NAME}' com ${FILE}."
read -r -p "Confirma? (digite 'sim'): " CONFIRM
[ "$CONFIRM" = "sim" ] || { echo "Cancelado."; exit 1; }

echo "→ Restaurando ${FILE} em '${DB_NAME}' ..."
# --clean --if-exists derruba objetos antes de recriar; --no-owner ignora dono.
docker compose exec -T db pg_restore -U "$DB_USER" -d "$DB_NAME" \
  --clean --if-exists --no-owner --no-privileges < "$FILE"

echo "✓ Restauração concluída."
