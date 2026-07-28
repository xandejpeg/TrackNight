#!/usr/bin/env bash
# TrackNight — Setup completo no VPS (rodar como root)
set -euo pipefail

DOMAIN=tracknightracing.com.br
APP_DIR=/var/www/tracknight
ENV_FILE=/etc/tracknight.env

echo "════════════════════════════════════════"
echo "  TrackNight setup — $DOMAIN"
echo "════════════════════════════════════════"

cd "$APP_DIR"

# 1. Env: garante variáveis essenciais
echo "==> [1/7] env"
grep -q '^APP_HOST=' "$ENV_FILE" || echo "APP_HOST=$DOMAIN" >> "$ENV_FILE"
grep -q '^ALLOWED_HOSTS=' "$ENV_FILE" || echo "ALLOWED_HOSTS=$DOMAIN,www.$DOMAIN" >> "$ENV_FILE"
grep -q '^FORCE_SSL=' "$ENV_FILE" || echo "FORCE_SSL=false" >> "$ENV_FILE"  # true depois do certbot

# Senha do banco: deixa vazia se for trust auth local
if sudo -u postgres psql track_night_production -c "SELECT 1;" >/dev/null 2>&1; then
  echo "   banco: trust auth local (sem senha)"
  grep -q '^TRACK_NIGHT_DATABASE_PASSWORD=' "$ENV_FILE" || echo "TRACK_NIGHT_DATABASE_PASSWORD=" >> "$ENV_FILE"
fi

# Admin inicial
grep -q '^ADMIN_USERNAME=' "$ENV_FILE" || echo "ADMIN_USERNAME=xandaoadmin" >> "$ENV_FILE"
grep -q '^ADMIN_INITIAL_PASSWORD=' "$ENV_FILE" || echo "ADMIN_INITIAL_PASSWORD=xandaos2@" >> "$ENV_FILE"

echo "   env keys: $(grep -c '^[A-Z]' "$ENV_FILE") variáveis"

# 2. Bundle
echo "==> [2/7] bundle install"
sudo -u deploy bash -lc "cd $APP_DIR && set -a && source $ENV_FILE && set +a && bundle install --quiet"

# 3. Migrations
echo "==> [3/7] db:migrate"
sudo -u deploy bash -lc "cd $APP_DIR && set -a && source $ENV_FILE && set +a && bundle exec rails db:migrate" 2>&1 | tail -15

# 4. Consolidação de dados (ACF+AC → xandao, ownership)
echo "==> [4/7] consolidação de dados"
sudo -u deploy bash -lc "cd $APP_DIR && set -a && source $ENV_FILE && set +a && bundle exec rails runner '
driver = Driver.find_by(slug: \"alessandro-chiarelli\")
if driver
  acf = DriverProfile.find_by(code: \"ACF\")
  ac  = DriverProfile.find_by(code: \"AC\")
  if ac && acf
    RaceSession.where(driver_profile: ac).update_all(driver_profile_id: acf.id)
    ResultEntry.where(driver_profile: ac).update_all(driver_profile_id: acf.id)
    ac.destroy!
    puts \"AC consolidado em ACF\"
  end
  xandao = User.find_or_initialize_by(username: \"xandao\")
  xandao.full_name = \"Alessandro Chiarele Filho\"
  xandao.cpf = \"17453596726\"
  xandao.password = \"Xandaos2@\" if xandao.new_record?
  xandao.must_change_password = false
  xandao.role = :member
  xandao.save!
  admin = User.find_or_initialize_by(username: \"xandaoadmin\")
  admin.full_name = \"Administrador TrackNight\"
  admin.password = \"xandaos2@\" if admin.new_record?
  admin.must_change_password = false
  admin.role = :admin
  admin.save!(validate: false)
  [driver, *RaceSession.all, *SourceDocument.all, *ImportBatch.all].each do |r|
    r.update_column(:user_id, xandao.id) if r.respond_to?(:user_id) && r.user_id != xandao.id
  end
  %w[Xande Helo].each { |n| u = User.find_by(username: n); u&.update_columns(full_name: nil, cpf: nil) }
  puts \"xandao id=#{xandao.id} admin id=#{admin.id} ownership ok\"
else
  puts \"driver alessandro-chiarelli nao encontrado — pulando consolidacao\"
end
'"

# 5. Assets
echo "==> [5/7] assets:precompile"
sudo -u deploy bash -lc "cd $APP_DIR && set -a && source $ENV_FILE && set +a && bundle exec rails assets:precompile --quiet" 2>&1 | tail -3

# 6. Restart app + jobs
echo "==> [6/7] restart serviços"
systemctl restart tracknight 2>/dev/null || bash "$APP_DIR/script/deploy.sh" "$DOMAIN"
sleep 5
systemctl is-active --quiet tracknight && echo "   ✓ app ativo" || echo "   ✗ app FALHOU"

# 7. Nginx + certbot
echo "==> [7/7] nginx + https"
bash "$APP_DIR/script/deploy.sh" "$DOMAIN" 2>&1 | tail -10

echo ""
echo "════════════════════════════════════════"
echo "  ✅ SETUP CONCLUÍDO"
echo "════════════════════════════════════════"
curl -sf -o /dev/null -w "  /up local:  %{http_code}\n" http://127.0.0.1:3000/up || echo "  ✗ local FALHOU"
curl -sf -o /dev/null -w "  /up https:  %{http_code}\n" "https://$DOMAIN/up" 2>/dev/null || echo "  ⚠ https pendente (certbot)"
