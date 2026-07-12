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
# Geometria traçada ponto a ponto sobre a foto aérea oficial do traçado 101
# (KGV Race Tracks — linha azul). Sentido horário conforme a seta do mapa.
# As divisões de setores NÃO possuem fonte oficial — permanecem pendentes de
# confirmação e podem ser ajustadas manualmente.
# Linha central extraída automaticamente da linha azul da foto oficial
# (máscara de cor + esqueletização Zhang-Suen + ordenação do loop).
# 93 pontos, sentido horário conforme a seta do mapa (→ no retão superior).
circuito_101_points = [
  [ 743, 30 ], [ 787, 30 ], [ 831, 30 ], [ 875, 30 ], [ 908, 48 ], [ 915, 89 ],
  [ 904, 129 ], [ 904, 173 ], [ 922, 204 ], [ 950, 246 ], [ 970, 283 ], [ 968, 325 ],
  [ 930, 365 ], [ 893, 382 ], [ 851, 393 ], [ 807, 398 ], [ 765, 402 ], [ 721, 404 ],
  [ 677, 406 ], [ 633, 409 ], [ 589, 411 ], [ 547, 413 ], [ 506, 406 ], [ 464, 378 ],
  [ 433, 340 ], [ 406, 301 ], [ 378, 261 ], [ 365, 222 ], [ 384, 186 ], [ 426, 175 ],
  [ 466, 202 ], [ 479, 237 ], [ 503, 272 ], [ 545, 257 ], [ 585, 222 ], [ 627, 180 ],
  [ 664, 162 ], [ 701, 173 ], [ 732, 208 ], [ 741, 252 ], [ 752, 294 ], [ 785, 325 ],
  [ 827, 321 ], [ 851, 285 ], [ 847, 241 ], [ 838, 197 ], [ 831, 153 ], [ 816, 111 ],
  [ 750, 98 ], [ 706, 98 ], [ 662, 98 ], [ 618, 98 ], [ 574, 98 ], [ 530, 98 ],
  [ 486, 98 ], [ 442, 98 ], [ 398, 98 ], [ 354, 109 ], [ 321, 127 ], [ 283, 169 ],
  [ 272, 211 ], [ 274, 255 ], [ 288, 296 ], [ 301, 329 ], [ 303, 371 ], [ 272, 402 ],
  [ 235, 415 ], [ 191, 422 ], [ 147, 424 ], [ 103, 424 ], [ 59, 415 ], [ 30, 384 ],
  [ 56, 345 ], [ 96, 323 ], [ 136, 294 ], [ 160, 257 ], [ 169, 215 ], [ 166, 171 ],
  [ 166, 127 ], [ 173, 85 ], [ 197, 54 ], [ 237, 43 ], [ 281, 39 ], [ 325, 37 ],
  [ 369, 37 ], [ 413, 34 ], [ 457, 34 ], [ 501, 34 ], [ 545, 34 ], [ 589, 34 ],
  [ 633, 32 ], [ 677, 32 ], [ 721, 32 ]
].freeze

# Converte a poligonal em um caminho SVG suave (Catmull-Rom -> Bézier cúbica).
circuito_101_path = begin
  pts = circuito_101_points
  n = pts.size
  d = +"M #{pts[0][0]} #{pts[0][1]} "
  n.times do |i|
    p0 = pts[(i - 1) % n]
    p1 = pts[i]
    p2 = pts[(i + 1) % n]
    p3 = pts[(i + 2) % n]
    c1x = (p1[0] + (p2[0] - p0[0]) / 6.0).round(1)
    c1y = (p1[1] + (p2[1] - p0[1]) / 6.0).round(1)
    c2x = (p2[0] - (p3[0] - p1[0]) / 6.0).round(1)
    c2y = (p2[1] - (p3[1] - p1[1]) / 6.0).round(1)
    d << "C #{c1x} #{c1y}, #{c2x} #{c2y}, #{p2[0]} #{p2[1]} "
  end
  d << "Z"
end

circuito_101_geometry = {
  viewbox: "0 0 1000 560",
  svg_path: circuito_101_path,
  start: { x: 545, y: 34 },
  traced_from: "Linha azul da foto aérea oficial do traçado 101 (KGV Race Tracks) — extração automática da linha central",
  sectors_confirmed: false
}

layout101 = TrackLayout.find_or_create_by!(venue: kgv, slug: "circuito-101") do |l|
  l.name = "Circuito 101"
  l.length_meters = 1015
  l.direction = nil # sentido não confirmado por fonte oficial — pendente
  l.surface = "Asfalto"
  l.description = "Configuração 101 da pista adulta do KGV — 1.015 m, grau de dificuldade Iniciante segundo o mapa oficial de traçados. Utilizada em baterias de kart rental (troca rápida)."
  l.geometry = circuito_101_geometry
end
layout101.update!(geometry: circuito_101_geometry)

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
