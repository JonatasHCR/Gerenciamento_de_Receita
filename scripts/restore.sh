#!/usr/bin/env bash
# Restauração do banco a partir de um dump gerado por scripts/backup.sh.
# Uso:  ./scripts/restore.sh backups/receita_AAAAMMDD_HHMMSS.sql
#       ./scripts/restore.sh            (usa o backup mais recente)
set -euo pipefail

cd "$(dirname "$0")/.."

DB_USER="${POSTGRES_USER:-receita}"
DB_NAME="${POSTGRES_DB:-receita_dev}"

FILE="${1:-}"
if [ -z "$FILE" ]; then
  FILE="$(ls -1t backups/receita_*.sql backups/receita_*.dump 2>/dev/null | head -n1 || true)"
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
# Os backups novos sao .sql; os .dump antigos continuam restauraveis para nao
# inutilizar o que ja esta na pasta.
case "$FILE" in
  *.dump)
    docker compose exec -T db pg_restore -U "$DB_USER" -d "$DB_NAME" \
      --clean --if-exists --no-owner --no-privileges < "$FILE"
    ;;
  *)
    # ON_ERROR_STOP=1: sem isto o psql segue depois de um erro e sai com
    # codigo 0 tendo restaurado pela metade. O sed tira a linha
    # `SET transaction_timeout`, que clientes 17 escrevem e servidores mais
    # antigos nao conhecem.
    sed '/^SET transaction_timeout/d' "$FILE" \
      | docker compose exec -T db psql -v ON_ERROR_STOP=1 -U "$DB_USER" -d "$DB_NAME"
    ;;
esac

echo "✓ Restauração concluída."
