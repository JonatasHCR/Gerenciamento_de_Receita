# act_runner (CI/CD do Gitea)

Runner que executa os workflows em `.gitea/workflows/`. Neste projeto **uma única
máquina** faz tudo (Gitea + runner + produção), e o deploy **builda a imagem
localmente** (sem registry). Pré-requisito: **Docker** instalado e o Gitea acessível.

## Subir

```bash
# 1. nesta máquina (a mesma do servidor):
cp runner.env.example runner.env
#    edite runner.env: GITEA_INSTANCE_URL e GITEA_RUNNER_REGISTRATION_TOKEN
#    (token em: Gitea → Admin/Org/Repo → Actions → Runners → Create new runner)

# 2. registrar e iniciar
docker compose up -d

# 3. conferir
docker compose logs -f act_runner
```

Em **Gitea → Actions → Runners** o runner deve aparecer como **Idle/Online**.

## Preparar a pasta de produção (DEPLOY_PATH)

O deploy roda dentro de `/opt/gerencimento_receita` (caminho fixo, montado no job
pelo `config.yaml`). Crie-o **uma vez** como um clone do repositório:

```bash
sudo git clone http://10.0.0.114:3000/SEU_USUARIO/gerencimento_receita.git /opt/gerencimento_receita
cd /opt/gerencimento_receita
cp .env.production.example .env   # e preencha (POSTGRES_PASSWORD, RAILS_MASTER_KEY, ...)
mkdir -p backups
```

> Para usar outro caminho, troque-o **nos dois lugares**: `container.options` /
> `valid_volumes` do `config.yaml` **e** o secret `DEPLOY_PATH`. Eles têm que ser idênticos.

## Checklist

- [ ] Actions habilitado (Gitea `app.ini` `[actions] ENABLED = true` + repo Settings → Actions).
- [ ] `GITEA_INSTANCE_URL` alcança o Gitea (teste: `curl $GITEA_INSTANCE_URL`).
- [ ] Token de registro válido em `runner.env`.
- [ ] Label `ubuntu-latest` presente (em `config.yaml`) — bate com `runs-on:` dos workflows.
- [ ] `/opt/gerencimento_receita` é um clone git com `.env` preenchido e `backups/` criado.
- [ ] Secret **`DEPLOY_PATH`** cadastrado no repo (= `/opt/gerencimento_receita`).

## Observações

- O **CI** (testes + Brakeman + bundler-audit) roda em containers `ruby:3.3-slim` +
  service `postgres:16` — funciona com a config padrão.
- O **deploy** faz `docker compose up -d --build` no host (sem registry). O `docker.sock`
  do host é injetado em cada container de job **automaticamente pelo act_runner** — NÃO
  o monte de novo no `container.options` (causa `Duplicate mount point: /var/run/docker.sock`).
  O `container.options` monta só a pasta de deploy no mesmo caminho do host. Garanta que o
  usuário do runner tem acesso ao `/var/run/docker.sock`.
- `data/` guarda o registro do runner (`.runner`) — não versionar.
