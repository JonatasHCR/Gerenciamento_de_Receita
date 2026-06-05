# Gerenciamento de Receitas — UFC Engenharia

Sistema web para controle das **receitas operacionais** da UFC Engenharia. Substitui as
planilhas Excel mensais por um painel central, com faturamento, recebimentos, previsão,
contratos (centros de custo) e relatórios — tudo com controle de acesso e auditoria.

---

## O que o sistema faz

- **Dashboard** com KPIs do mês (faturado, recebido, em aberto, previsto), gráficos e os
  quadros **Previsto × Realizado** e **Faturado × Recebido** por cliente/centro de custo.
- **Centros de Custo (contratos):** cadastro com nº do contrato, cliente, objeto, datas de
  início/fim, valor, participação UFC e coordenador(es). Mostra **saldo** (valor − faturado
  principal) e permite registrar **reajustes** de valor/prazo com histórico.
- **Faturamento (Notas Fiscais):** lançamento de NFs, classificadas em **Principal** ou
  **Reajuste** (só o principal abate o saldo do contrato). Busca por número e filtro por
  situação (em aberto / quitadas / todas).
- **Recebimentos:** baixa de pagamentos vinculados às NFs (com pagamento parcial).
- **Previsão de Faturamento:** previsto por mês/centro de custo; o **realizado é calculado
  automaticamente** a partir do faturamento (não é digitado).
- **Relatórios:**
  - **Mensal em PDF** (por cliente → CC): previsto, faturado no mês, em aberto de meses
    anteriores, recebido e faturas em aberto.
  - **Relação de Compromissos em Excel** (por CC): contrato, contratante, objeto, início,
    fim, valor, % a executar e saldo.
- **Importação de planilha (.xlsx):** importa centros de custo, faturamento, recebimentos e
  previsão a partir do modelo; tolerante a erros (importa o que é válido e sinaliza o resto).
- **Usuários e perfis** (Devise + Pundit) e **auditoria** de todas as alterações (PaperTrail).

---

## Perfis de acesso

| Perfil | Acesso |
|---|---|
| **admin** | Tudo — inclui usuários e auditoria |
| **financeiro** | Faturamento, recebimentos, previsão, centros de custo |
| **gestor** | Previsão e centros de custo |
| **coordenador** | Previsão e centros de custo próprios |

---

## Stack

Rails 8 + Hotwire (Turbo/Stimulus) · PostgreSQL 16 · Tailwind CSS v4 (Propshaft) ·
Devise + Pundit · PaperTrail · Pagy · Chartkick · Prawn (PDF) / caxlsx (Excel) ·
roo (importação) · RSpec. Tudo roda em **Docker**.

---

## Como rodar (desenvolvimento)

Pré-requisito: **Docker** + **Docker Compose**.

```bash
# 1. variáveis de ambiente
cp .env.example .env        # ajuste se necessário

# 2. subir os serviços (web + db + backup)
docker compose up

# 3. preparar o banco (primeira vez), em outro terminal
docker compose exec web bin/rails db:prepare db:seed
```

App em **http://localhost:3040**.

**Credenciais de desenvolvimento (seed):**

| Email | Senha | Perfil |
|---|---|---|
| `admin@ufc.com.br` | `admin123456` | admin |

Comandos úteis:
```bash
docker compose exec web bin/rails <comando>
docker compose exec web bundle exec rspec        # testes
docker compose exec web bundle exec brakeman     # análise de segurança
```

---

## Como funciona (fluxo de uso)

1. **Cadastre o Centro de Custo** (contrato): CR, cliente, nº do contrato, objeto, valor,
   início/fim e coordenador(es).
2. **Lance o Faturamento** (NFs) vinculado ao CR, marcando **Principal** ou **Reajuste**.
3. **Registre os Recebimentos** das NFs (total ou parcial).
4. **Informe a Previsão** mensal (previsto); o realizado vem sozinho do faturamento.
5. Acompanhe tudo no **Dashboard** e gere os **relatórios** (PDF mensal / Excel de compromissos).
6. Reajustes de contrato (valor/prazo) ficam no **detalhe do Centro de Custo**, com histórico.

> **Importação:** em *Importar*, baixe o modelo `.xlsx`, preencha e envie. O sistema importa
> as linhas válidas, atualiza registros existentes e lista as linhas com erro.

---

## Backup

- **Automático a cada 12h** — serviço `backup` (sidecar) gera dumps em `backups/`
  (retém os 14 mais recentes). Configurável via `.env` (`BACKUP_INTERVAL_HOURS`, `BACKUP_KEEP`).
- **Manual:**
  ```bash
  ./scripts/backup.sh                 # gera um dump
  ./scripts/restore.sh [arquivo]      # restaura (pede confirmação)
  ```
- **Pré-deploy:** o pipeline faz backup do banco antes de cada deploy.

---

## Produção e CI/CD

- **Produção:** `docker-compose.prod.yml` + `.env` (modelo em `.env.production.example`).
- **CI/CD (Gitea Actions):** `.gitea/workflows/` — `ci.yml` (testes + segurança a cada push)
  e `deploy.yml` (build da imagem → push no registry → deploy via SSH com **backup,
  migração, healthcheck e rollback automático**).
- **Runner:** instruções e arquivos em `runner/` (act_runner).

---
