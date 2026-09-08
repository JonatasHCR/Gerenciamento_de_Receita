#!/usr/bin/env bash
# Backup do banco PostgreSQL rodando no container `db` (docker compose).
# Uso:  ./scripts/backup.sh
# Saída: backups/receita_AAAAMMDD_HHMMSS.sql  (texto puro, restaurável com psql)
set -euo pipefail

cd "$(dirname "$0")/.."

DB_USER="${POSTGRES_USER:-receita}"
DB_NAME="${POSTGRES_DB:-receita_dev}"
KEEP="${BACKUP_KEEP:-14}"          # quantos backups manter
DIR="backups"
TS="$(date +%Y%m%d_%H%M%S)"
FILE="${DIR}/receita_${TS}.sql"

mkdir -p "$DIR"

echo "→ Gerando backup de '${DB_NAME}' em ${FILE} ..."
docker compose exec -T db pg_dump -U "$DB_USER" -d "$DB_NAME" --clean --if-exists --no-owner --no-privileges > "$FILE"

SIZE="$(du -h "$FILE" | cut -f1)"
echo "✓ Backup concluído (${SIZE})."

# Retenção: mantém apenas os $KEEP backups mais recentes.
COUNT="$(ls -1 ${DIR}/receita_*.sql 2>/dev/null | wc -l | tr -d ' ')"
if [ "$COUNT" -gt "$KEEP" ]; then
  ls -1t ${DIR}/receita_*.sql | tail -n +$((KEEP + 1)) | xargs -r rm --
  echo "✓ Retenção aplicada: mantidos os ${KEEP} backups mais recentes."
fi
