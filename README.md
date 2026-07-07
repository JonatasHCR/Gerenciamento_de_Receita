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
- **Coordenadores (internos × externos):** um CC pode ter coordenadores **internos**
  (usuários do sistema) e **externos** (apenas o nome, sem login). Os internos são
  **vinculados automaticamente** aos seus centros de custo pelo nome — passam a enxergá-los
  e a lançar previsão. O vínculo também pode ser gerido na tela de **Usuários** (admin).
- **Faturamento (Notas Fiscais):** lançamento de NFs, classificadas em **Principal** ou
  **Reajuste** (só o principal abate o saldo do contrato). Busca por número e filtro por
  situação (em aberto / quitadas / todas).
- **Recebimentos:** baixa de pagamentos vinculados às NFs (com pagamento parcial).
- **Previsão de Faturamento:** previsto por mês/centro de custo; o **realizado é calculado
  automaticamente** a partir do faturamento (não é digitado).
- **Relatórios** (aba dedicada que centraliza todos):
  - **Mensal em PDF** (por cliente → CC): previsto, faturado, em aberto de meses anteriores,
    recebido e faturas em aberto. Pode ser gerado por **mês** ou por **período** (intervalo
    de datas) — no período, os valores são acumulados e o "em aberto" reflete o fim do período.
  - **Relação de Compromissos em Excel** (por CC): contrato, contratante, objeto, início,
    fim, valor, % a executar e saldo.
  - **Relação das Faturas em Aberto** (PDF **e** Excel): NFs com saldo em aberto agrupadas por
    cliente → centro de custo (CLIENTE, NF, emissão, CC, contrato, valor), com subtotais por CC
    e total. Escolha **um ou mais clientes**; as faturas **parcialmente pagas** ficam destacadas.
- **Importação de planilha (.xlsx):** importe tudo de uma vez ou **por partes** — marque o
  que quer importar (centros de custo, faturamento, recebimentos, previsão) e o **modelo
  baixado reflete a escolha**. Admins também podem **importar usuários**. Tolerante a erros:
  importa as linhas válidas e sinaliza as demais.
- **Usuários e perfis** (Devise + Pundit) e **auditoria** de todas as alterações (PaperTrail).

---

## Perfis de acesso

| Perfil | Acesso |
|---|---|
| **admin** | Tudo — inclui usuários, auditoria e importação de usuários |
| **financeiro** | Faturamento, recebimentos, previsão, centros de custo, importação |
| **gestor** | Previsão e centros de custo; cria clientes e centros de custo |
| **coordenador** | Previsão e centros de custo **próprios**; cria clientes e centros de custo (o CC criado já fica vinculado a ele) |

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

**Credenciais de desenvolvimento (seed):** o `db:seed` cria estes dados **apenas fora
de produção** (admin + usuários e massa de dados fictícios). Em produção o seed é
ignorado — o admin é criado pela task `admin:create` (ver seção Produção).

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

> **Importação:** em *Importar*, escolha **o que** importar (tudo ou só alguns tipos),
> baixe o modelo `.xlsx` correspondente, preencha e envie. O sistema importa as linhas
> válidas, atualiza registros existentes e lista as linhas com erro. Admins também podem
> importar **usuários** (aba `USUARIOS` do modelo).

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

Cenário de **servidor único** (Gitea + runner + produção na mesma máquina) — a imagem
é **construída localmente no servidor, sem registry**.

- **Produção:** `docker-compose.prod.yml` (builda a imagem local) + `.env`
  (modelo em `.env.production.example`). Fica em `/opt/gerencimento_receita` (um clone git).
- **CI/CD (Gitea Actions):** `.gitea/workflows/` — `ci.yml` (testes + segurança a cada push)
  e `deploy.yml` (na `main`/`master`: backup → `git reset` no commit → `up -d --build` →
  migração → healthcheck `/up` → **rollback automático** para o commit anterior se falhar).
- **Runner:** instruções e arquivos em `runner/` (act_runner). Único secret necessário:
  `DEPLOY_PATH`.

### Admin inicial (produção)

O seed **não** cria admin em produção (e não carrega dados de demonstração). Após o
primeiro deploy, crie o admin uma vez com a task dedicada, definindo `ADMIN_EMAIL` e
`ADMIN_PASSWORD` (já presentes no `.env` de produção):

```bash
cd /opt/gerencimento_receita
docker compose -f docker-compose.prod.yml exec web bin/rails admin:create
```

A task **cria** o admin se não existir ou **atualiza a senha** se já existir. Troque a
senha no primeiro login.

---
