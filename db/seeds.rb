# Dados estruturais do TrackNight (sem resultados — estes vêm do pipeline de importação).

# --- Usuários ----------------------------------------------------------------
xande = User.find_or_initialize_by(username: "Xande")
if xande.new_record?
  password = ENV.fetch("XANDE_INITIAL_PASSWORD") { Rails.env.production? ? raise("Defina XANDE_INITIAL_PASSWORD") : "123321" }
  xande.password = password
  xande.must_change_password = Rails.env.production?
  xande.save!
end

helo = User.find_or_initialize_by(username: "Helo")
if helo.new_record?
  password = ENV.fetch("HELO_INITIAL_PASSWORD") { Rails.env.production? ? raise("Defina HELO_INITIAL_PASSWORD") : "123321" }
  helo.password = password
  helo.must_change_password = Rails.env.production?
  helo.save!
end

# --- Piloto e perfis ---------------------------------------------------------
driver = Driver.find_or_create_by!(slug: "alessandro-chiarelli") { |d| d.name = "Alessandro Chiarelli" }

[
  "Alessandro Chiarelli",
  "Alessandro Chiareli",
  "Alessandro Chiarele",
  "ALESSANDRO CHIARELE"
].each do |name|
  normalized = DriverAlias.normalize_name(name)
  DriverAlias.find_or_create_by!(normalized_name: normalized) { |a| a.driver = driver; a.name = name }
end

DriverProfile.find_or_create_by!(code: "ACF") do |p|
  p.driver = driver
  p.display_name = "ACF"
  p.kind = :main
  p.color = "#e10600"
end

DriverProfile.find_or_create_by!(code: "AC") do |p|
  p.driver = driver
  p.display_name = "AC (smurf)"
  p.kind = :smurf
  p.color = "#00a8e8"
end

# --- Pista: KGV --------------------------------------------------------------
kgv = Venue.find_or_create_by!(slug: "kgv") do |v|
  v.name = "Kartódromo Internacional Granja Viana"
  v.short_name = "KGV"
  v.address = "R. Tomás Sepé, 443 - Jardim da Glória"
  v.city = "Cotia"
  v.state = "SP"
  v.country = "Brasil"
  v.latitude = -23.605833
  v.longitude = -46.836111
  v.website = "https://kgvracetracks.com/granja-viana"
  v.area_m2 = 48_000
  v.opened_on = Date.new(1996, 10, 1)
  v.description = "O kartódromo mais tradicional do Brasil, inaugurado em outubro de 1996 pela família Giaffone. " \
                  "Pista adulta de 1.150m com dezenas de configurações de traçado, palco das 500 Milhas de Kart, " \
                  "Copa São Paulo e provas de Endurance Rental."
end

# --- Traçado: Circuito 101 ---------------------------------------------------
# Geometria aproximada, traçada manualmente sobre o mapa oficial (KGV Race Tracks).
# As divisões de setores NÃO possuem fonte oficial — permanecem pendentes de
# confirmação e podem ser ajustadas manualmente.
circuito_101_path = "M 150 430 C 120 470 140 505 185 495 C 230 485 250 455 275 460 " \
  "C 320 468 420 472 520 470 C 575 468 620 462 648 435 C 668 415 660 392 630 388 " \
  "C 600 385 585 400 560 405 C 535 410 520 398 525 375 C 532 352 560 350 580 338 " \
  "C 604 322 606 296 585 282 C 560 267 530 277 515 298 C 500 318 480 330 458 322 " \
  "C 436 314 432 292 448 275 C 464 259 490 258 512 250 C 540 240 560 220 555 200 " \
  "C 548 178 520 172 490 176 C 420 184 320 190 240 196 C 200 200 175 210 168 240 " \
  "C 162 268 175 290 172 320 C 170 355 158 395 150 430 Z"

layout101 = TrackLayout.find_or_create_by!(venue: kgv, slug: "circuito-101") do |l|
  l.name = "Circuito 101"
  l.length_meters = 1015
  l.direction = nil # sentido não confirmado por fonte oficial — pendente
  l.surface = "Asfalto"
  l.description = "Configuração 101 da pista adulta do KGV — 1.015 m, grau de dificuldade Iniciante segundo o mapa oficial de traçados. Utilizada em baterias de kart rental (troca rápida)."
  l.geometry = {
    viewbox: "80 140 620 400",
    svg_path: circuito_101_path,
    start: { x: 400, y: 471 },
    traced_from: "Mapa oficial de traçados KGV Race Tracks (Julho) — aproximação manual",
    sectors_confirmed: false
  }
end

(1..3).each do |n|
  TrackSector.find_or_create_by!(track_layout: layout101, number: n) do |s|
    s.name = "S#{n}"
    s.description = "Setor #{n} da telemetria KGV (limites físicos não confirmados por fonte oficial)"
    s.boundary_confirmed = false
  end
end

# --- Fontes das informações da pista ----------------------------------------
[
  {
    title: "KGV Race Tracks — Granja Viana (site oficial)",
    url: "https://kgvracetracks.com/granja-viana",
    publisher: "KGV Race Tracks / J L Indústria e Comércio Ltda",
    reliability: "alta",
    notes: "Pista adulta de 1.150m, área de 48.000 m², endereço e estrutura."
  },
  {
    title: "Traçados Granja Viana — mapa oficial do Circuito 101",
    url: "https://kgvracetracks.com/granja-viana/tracados",
    publisher: "KGV Race Tracks",
    reliability: "alta",
    notes: "Imagem oficial do traçado 101: 1.015 m, grau de dificuldade Iniciante, configurações mensais de cone."
  },
  {
    title: "Kartódromo Internacional Granja Viana — Wikipédia",
    url: "https://pt.wikipedia.org/wiki/Kart%C3%B3dromo_Internacional_Granja_Viana",
    publisher: "Wikipédia (CC BY-SA 4.0)",
    reliability: "media",
    notes: "Inauguração em outubro/1996, coordenadas 23°36'21\"S 46°50'10\"O, homologação internacional, 500 Milhas."
  }
].each do |src|
  TrackSource.find_or_create_by!(title: src[:title]) do |s|
    s.venue = kgv
    s.track_layout = layout101
    s.url = src[:url]
    s.publisher = src[:publisher]
    s.reliability = src[:reliability]
    s.notes = src[:notes]
    s.accessed_on = Date.new(2026, 7, 11)
  end
end

TrackAsset.find_or_create_by!(track_layout: layout101, kind: "image", title: "Mapa oficial do traçado 101 (Julho)") do |a|
  a.source_url = "https://lh3.googleusercontent.com/d/15_zrEzF87OPPguRjUv9flc09TgUm07RK=w800"
  a.notes = "Imagem publicada pela KGV Race Tracks na página de traçados."
end

# --- Modalidade --------------------------------------------------------------
VehicleCategory.find_or_create_by!(slug: "kart-rental") do |c|
  c.name = "Kart Rental"
  c.vehicle_kind = :kart
end

puts "Seeds ok: usuários Xande e Helo, piloto Alessandro Chiarelli (ACF + AC), KGV Circuito 101, Kart Rental."
