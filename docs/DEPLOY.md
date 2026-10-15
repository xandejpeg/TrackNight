# TrackNight — Deploy e Infraestrutura

Guia completo de produção: VPS, domínio, banco gerenciado (Neon) e HTTPS.

---

## 1. Pré-requisitos

| Item | Valor |
|---|---|
| VPS | **KVM 2 Hostinger** — `srv1559282.hstgr.cloud` (Ubuntu 24.04) |
| IP | **`76.13.169.45`** |
| Domínio | `tracknightracing.com.br` |
| App | `/var/www/tracknight` |
| Usuário | `deploy` |
| Ruby | 3.3.x (via rbenv) |
| Banco | PostgreSQL local **ou** Neon (ver §3) |

---

## 2. Configuração inicial do servidor (uma vez)

```bash
# 1. Clonar o app
git clone <repo> /var/www/tracknight
chown -R deploy:deploy /var/www/tracknight

# 2. Variáveis de ambiente
cp /var/www/tracknight/.env.production.example /etc/tracknight.env
nano /etc/tracknight.env   # preencher: MASTER_KEY, DB, APP_HOST, SMTP, ADMIN_*
chmod 600 /etc/tracknight.env

# 3. Deploy (instala deps, sobe systemd + nginx)
cd /var/www/tracknight
sudo bash script/deploy.sh tracknight.app
```

O script é **idempotente** — rode de novo a cada atualização (`git pull` + deploy).

---

## 3. Banco de dados: Neon (serverless Postgres)

O app usa **4 bancos** (Solid Cache/Queue/Cable exigem separados). No Neon, crie um projeto e 4 databases:

```
tracknight          → primary (DATABASE_URL)
tracknight_cache    → cache   (CACHE_DATABASE_URL)
tracknight_queue    → queue   (QUEUE_DATABASE_URL)
tracknight_cable    → cable   (CABLE_DATABASE_URL)
```

### Migração do banco local → Neon

```bash
# No servidor (banco local atual)
pg_dump -U track_night -h localhost track_night_production | gzip > /tmp/tn_primary.sql.gz
pg_dump -U track_night -h localhost track_night_production_cache | gzip > /tmp/tn_cache.sql.gz
pg_dump -U track_night -h localhost track_night_production_queue | gzip > /tmp/tn_queue.sql.gz
pg_dump -U track_night -h localhost track_night_production_cable | gzip > /tmp/tn_cable.sql.gz

# Restore no Neon (connection string do dashboard Neon, com sslmode=require)
gunzip -c /tmp/tn_primary.sql.gz | psql "postgres://user:pass@host.neon.tech/tracknight?sslmode=require"
gunzip -c /tmp tn_cache.sql.gz   | psql "postgres://user:pass@host.neon.tech/tracknight_cache?sslmode=require"
gunzip -c /tmp/tn_queue.sql.gz   | psql "postgres://user:pass@host.neon.tech/tracknight_queue?sslmode=require"
gunzip -c /tmp/tn_cable.sql.gz   | psql "postgres://user:pass@host.neon.tech/tracknight_cable?sslmode=require"

# Smoke test: conferir contagem de linhas nas tabelas principais
# Depois: preencher as 4 *_DATABASE_URL em /etc/tracknight.env e reiniciar
sudo systemctl restart tracknight tracknight-jobs
```

> **Janela de manutenção:** pare o app (`systemctl stop tracknight`) durante o dump/restore para não gravar dados novos no banco velho.

---

## 4. Domínio

1. **Registrar** o domínio — ✅ `tracknightracing.com.br` (registrando na Hostinger).
2. **DNS:** criar registro `A` apontando para o IP da VPS (`76.13.169.45`).
   - `tracknightracing.com.br` → A → `76.13.169.45`
   - `www.tracknightracing.com.br` → CNAME → `tracknightracing.com.br`
3. Aguardar propagação (`dig tracknightracing.com.br`).
4. Atualizar `/etc/tracknight.env`: `APP_HOST` e `ALLOWED_HOSTS`.
5. Rodar `sudo bash script/deploy.sh tracknightracing.com.br` — o certbot emite o HTTPS automaticamente.

### Redirect do domínio antigo (se houver)

Se `xandaopiloto.com` continuar ativo, manter um server block no nginx respondendo 301 por 60–90 dias:

```nginx
server {
    listen 80;
    server_name xandaopiloto.com www.xandaopiloto.com;
    return 301 https://tracknightracing.com.br$request_uri;
}
```

---

## 5. Atualizações do app (deploy contínuo)

```bash
cd /var/www/tracknight
sudo -u deploy git pull
sudo bash script/deploy.sh tracknightracing.com.br   # idempotente: gems, assets, migrate, restart
```

Para zero-downtime, o Puma faz phased restart automaticamente (`systemctl reload`).

---

## 6. Monitoramento

- **Health check:** `GET https://tracknightracing.com.br/up` → 200 (configurar no UptimeRobot/BetterStack).
- **Logs app:** `journalctl -u tracknight -f`
- **Logs jobs (OCR):** `journalctl -u tracknight-jobs -f`
- **Nginx:** `tail -f /var/log/nginx/access.log`

### Alertas mínimos recomendados

| Checagem | Frequência | Ação |
|---|---|---|
| `/up` retorna 200 | 1 min | página de status + alerta |
| Certificado expira em < 15 dias | diária | certbot auto-renova; alertar se falhar |
| Disco > 80% | diária | limpar `storage/` antigo ou aumentar volume |

---

## 7. Storage de uploads (futuro)

Hoje os arquivos (fotos de resultado) ficam em `storage/` local. Quando escalar:

1. Criar bucket S3/R2.
2. Preencher credenciais em `/etc/tracknight.env` + `config/storage.yml`.
3. `ACTIVE_STORAGE_SERVICE=amazon` (ou `r2`).
4. Migrar blobs existentes com `rails active_storage:mirror` ou script de sync.

---

## 8. Checklist de go-live

```
[ ] Domínio registrado + DNS apontando (tracknightracing.com.br → 76.13.169.45)
[ ] /etc/tracknight.env preenchido (MASTER_KEY, DB, APP_HOST, ADMIN_*, SMTP)
[ ] Neon: 4 databases criados + migrados (ou Postgres local)
[ ] script/deploy.sh executado sem erros
[ ] https://tracknightracing.com.br carrega a landing
[ ] Cadastro de conta teste funciona
[ ] Login admin (ADMIN_USERNAME) + troca de senha
[ ] Upload de foto de resultado → OCR → revisão → confirmação
[ ] /up monitorado (UptimeRobot)
[ ] Certificado HTTPS ativo (cadeado)
```
