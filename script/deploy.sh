#!/usr/bin/env bash
# TrackNight — Deploy para VPS (Ubuntu/Debian)
# Uso: sudo ./script/deploy.sh [dominio]
# Ex.: sudo ./script/deploy.sh tracknight.app
#
# Idempotente: pode rodar de novo para atualizar. Assume:
#   - código em /var/www/tracknight (git clone/pull feito antes)
#   - usuário 'deploy' existe
#   - PostgreSQL local OU DATABASE_URL em /etc/tracknight.env
#   - /etc/tracknight.env preenchido (ver .env.production.example)

set -euo pipefail

DOMAIN="${1:-tracknightracing.com.br}"
APP_DIR=/var/www/tracknight
ENV_FILE=/etc/tracknight.env
APP_USER=deploy

echo "==> Deploy TrackNight em ${DOMAIN}"

[[ -f "$ENV_FILE" ]] || { echo "ERRO: $ENV_FILE não existe. Copie .env.production.example e preencha."; exit 1; }

# ─── Dependências ────────────────────────────────────────────────────────────
echo "==> Instalando dependências do sistema"
apt-get update -qq
apt-get install -y -qq build-essential libpq-dev libyaml-dev pkg-config \
  nginx certbot python3-certbot-nginx imagemagick libvips42 \
  tesseract-ocr tesseract-ocr-por poppler-utils

# Ruby via rbenv/rvm assumido instalado para $APP_USER
# ─── App ─────────────────────────────────────────────────────────────────────
echo "==> Instalando gems e assets"
cd "$APP_DIR"
sudo -u $APP_USER bash -lc "
  set -a; source $ENV_FILE; set +a
  bundle install --deployment --without development test
  bundle exec rails assets:precompile
  bundle exec rails db:prepare
"

# ─── Systemd ─────────────────────────────────────────────────────────────────
echo "==> Configurando systemd"
cat > /etc/systemd/system/tracknight.service <<EOF
[Unit]
Description=TrackNight Puma
After=network.target

[Service]
Type=simple
User=$APP_USER
WorkingDirectory=$APP_DIR
EnvironmentFile=$ENV_FILE
Environment=PATH=/usr/local/bin:/usr/bin:/bin
ExecStart=/usr/local/bin/bundle exec puma -C config/puma.rb
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

# Solid Queue (jobs: OCR, etc.)
cat > /etc/systemd/system/tracknight-jobs.service <<EOF
[Unit]
Description=TrackNight Solid Queue
After=network.target

[Service]
Type=simple
User=$APP_USER
WorkingDirectory=$APP_DIR
EnvironmentFile=$ENV_FILE
ExecStart=/usr/local/bin/bundle exec rake solid_queue:start
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now tracknight tracknight-jobs
sleep 6
systemctl is-active --quiet tracknight && echo "  ✓ app" || { echo "  ✗ app FALHOU"; journalctl -u tracknight -n 20 --no-pager; exit 1; }
systemctl is-active --quiet tracknight-jobs && echo "  ✓ jobs" || echo "  ⚠ jobs (ver journalctl -u tracknight-jobs)"

# ─── Nginx ───────────────────────────────────────────────────────────────────
echo "==> Configurando nginx"
cat > /etc/nginx/sites-available/tracknight <<EOF
server {
    listen 80;
    server_name ${DOMAIN} www.${DOMAIN};
    client_max_body_size 25m;

    location / {
        proxy_pass http://127.0.0.1:3000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
    }
}
EOF
ln -sf /etc/nginx/sites-available/tracknight /etc/nginx/sites-enabled/tracknight
rm -f /etc/nginx/sites-enabled/default
nginx -t
systemctl enable --now nginx
systemctl reload nginx

# ─── Health check ────────────────────────────────────────────────────────────
echo "==> Health check"
curl -sf -o /dev/null -w "  local:%{http_code}\n" http://127.0.0.1:3000/up || echo "  ✗ local FALHOU"
curl -sf -o /dev/null -w "  nginx:%{http_code}\n" -H "Host: ${DOMAIN}" http://127.0.0.1/up || echo "  ✗ nginx FALHOU"

# ─── HTTPS ───────────────────────────────────────────────────────────────────
echo "==> HTTPS (certbot)"
if curl -sf "http://${DOMAIN}/up" -o /dev/null; then
  certbot --nginx -d "${DOMAIN}" -d "www.${DOMAIN}" --non-interactive --agree-tos \
    -m "admin@${DOMAIN}" --redirect || echo "  ⚠ certbot falhou — rode manualmente depois"
else
  echo "  ⚠ domínio ainda não resolve — pulando certbot. Rode depois:"
  echo "    certbot --nginx -d ${DOMAIN} -d www.${DOMAIN}"
fi

echo ""
echo "=== DEPLOY OK: https://${DOMAIN} ==="
