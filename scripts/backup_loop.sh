#!/usr/bin/env bash
# Loop de backup — roda dentro do serviço "backup" (imagem postgres).
# Faz backup a cada BACKUP_INTERVAL_HOURS horas, alinhado ao relógio
# (ex.: 12 → 00:00 e 12:00), gera o dump e aplica retenção.
set -uo pipefail

DIR="/backups"
KEEP="${BACKUP_KEEP:-14}"
INTERVAL="${BACKUP_INTERVAL_HOURS:-12}"   # de quantas em quantas horas
DB_HOST="${DB_HOST:-db}"

mkdir -p "$DIR"
echo "[backup] iniciado — a cada ${INTERVAL}h, retenção ${KEEP}, destino ${DIR}"

while true; do
  now="$(date +%s)"
  hour="$(date +%-H)"
  # próxima hora múltipla do intervalo
  next_hour="$(( ((hour / INTERVAL) + 1) * INTERVAL ))"
  if [ "$next_hour" -ge 24 ]; then
    next="$(date -d "tomorrow $((next_hour - 24)):00" +%s)"
  else
    next="$(date -d "today ${next_hour}:00" +%s)"
  fi
  sleep "$((next - now))"

  ts="$(date +%Y%m%d_%H%M%S)"
  file="${DIR}/receita_${ts}.dump"
  if pg_dump -h "$DB_HOST" -U "$POSTGRES_USER" -d "$POSTGRES_DB" -Fc > "$file"; then
    echo "[backup] OK ${file} ($(du -h "$file" | cut -f1))"
  else
    echo "[backup] FALHOU em ${ts}" >&2
    rm -f "$file"
  fi

  # Retenção: mantém apenas os $KEEP mais recentes (apenas os automáticos).
  ls -1t "${DIR}"/receita_*.dump 2>/dev/null | tail -n +"$((KEEP + 1))" | xargs -r rm --
done
