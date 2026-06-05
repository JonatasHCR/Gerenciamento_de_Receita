# act_runner (CI/CD do Gitea)

Runner que executa os workflows em `.gitea/workflows/`. Rode na máquina do runner
(separada do Gitea). Pré-requisito: **Docker** instalado e o Gitea acessível pela rede.

## Subir

```bash
# 1. nesta máquina do runner:
cp runner.env.example runner.env
#    edite runner.env: GITEA_INSTANCE_URL e GITEA_RUNNER_REGISTRATION_TOKEN
#    (token em: Gitea → Admin/Org/Repo → Actions → Runners → Create new runner)

# 2. registrar e iniciar
docker compose up -d

# 3. conferir
docker compose logs -f act_runner
```

Em **Gitea → Actions → Runners** o runner deve aparecer como **Idle/Online**.

## Checklist

- [ ] Actions habilitado (Gitea `app.ini` `[actions] ENABLED = true` + repo Settings → Actions).
- [ ] `GITEA_INSTANCE_URL` alcança o Gitea a partir de 10.0.0.114 (teste: `curl $GITEA_INSTANCE_URL`).
- [ ] Token de registro válido em `runner.env`.
- [ ] Label `ubuntu-latest` presente (em `config.yaml`) — bate com `runs-on:` dos workflows.
- [ ] Secrets do deploy cadastrados no repo (REGISTRY_*, DEPLOY_*).

## Observações

- O **CI** (testes + Brakeman + bundler-audit) roda em containers `ruby:3.3-slim` +
  service `postgres:16` — funciona com a config padrão.
- O **deploy** faz `docker build/push` — por isso o socket do Docker é montado no job
  (`config.yaml` → `container.options`). Garanta que o usuário do runner tem acesso ao
  `/var/run/docker.sock`.
- `data/` guarda o registro do runner (`.runner`) — não versionar.
