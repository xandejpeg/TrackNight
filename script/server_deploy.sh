#!/usr/bin/env bash
# TrackNight — Deploy remoto (rodar NO VPS como root ou com sudo)
# Uso: bash /var/www/tracknight/script/server_deploy.sh
set -euo pipefail

DOMAIN=tracknightracing.com.br
APP_DIR=/var/www/tracknight
ENV_FILE=/etc/tracknight.env

echo "════════════════════════════════════════"
echo "  TrackNight deploy — $DOMAIN"
echo "════════════════════════════════════════"

# 1. Código novo
echo "==> [1/6] git pull"
cd "$APP_DIR"
sudo -u deploy git pull origin main

# 2. Backup do banco (segurança antes de migrar)
echo "==> [2/6] backup do banco"
mkdir -p /var/backups/tracknight
sudo -u postgres pg_dump track_night_production | gzip > "/var/backups/tracknight/pre_deploy_$(date +%Y%m%d_%H%M%S).sql.gz"
echo "   backup salvo em /var/backups/tracknight/"

# 3. Env (cria se não existir — NÃO sobrescreve se já existir)
if [[ ! -f "$ENV_FILE" ]]; then
  echo "==> [3/6] criando $ENV_FILE (PREENCHA DEPOIS!)"
  cp "$APP_DIR/.env.production.example" "$ENV_FILE"
  # MASTER_KEY automática do repo
  MASTER_KEY=$(cat "$APP_DIR/config/master.key" 2>/dev/null || echo "")
  [[ -n "$MASTER_KEY" ]] && sed -i "s|^RAILS_MASTER_KEY=.*|RAILS_MASTER_KEY=$MASTER_KEY|" "$ENV_FILE"
  chmod 600 "$ENV_FILE"
  echo "   ⚠️  EDITE $ENV_FILE: ADMIN_INITIAL_PASSWORD e TRACK_NIGHT_DATABASE_PASSWORD"
else
  echo "==> [3/6] $ENV_FILE já existe — ok"
fi

# 4. Gems, assets, migrations
echo "==> [4/6] bundle + assets + migrate"
sudo -u deploy bash -lc "
  cd $APP_DIR
  set -a; source $ENV_FILE; set +a
  bundle install --deployment --without development test --quiet
  bundle exec rails assets:precompile --quiet
  bundle exec rails db:migrate
"

# 5. Systemd + nginx + certbot
echo "==> [5/6] systemd + nginx + https"
bash "$APP_DIR/script/deploy.sh" "$DOMAIN"

# 6. Health check final
echo "==> [6/6] validação"
sleep 3
curl -sf -o /dev/null -w "   /up local:  %{http_code}\n" http://127.0.0.1:3000/up || echo "   ✗ app local FALHOU"
curl -sf -o /dev/null -w "   /up https:  %{http_code}\n" "https://$DOMAIN/up" || echo "   ⚠ https ainda não responde (certbot pode estar emitindo)"

echo ""
echo "════════════════════════════════════════"
echo "  ✅ DEPLOY CONCLUÍDO"
echo "  https://$DOMAIN"
echo "════════════════════════════════════════"
