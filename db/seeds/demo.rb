# Dados de demonstração do TrackNight — piloto e perfis FICTÍCIOS.
# Carregado apenas com: SEED_DEMO=1 bin/rails db:seed
# Útil para desenvolvimento: o pipeline de import/OCR precisa de um driver
# com aliases para reconhecer o piloto nas folhas de resultado.

driver = Driver.find_or_create_by!(slug: "piloto-demo") { |d| d.name = "Piloto Demo" }

[
  "Piloto Demo",
  "P Demo",
  "PILOTO D"
].each do |name|
  normalized = DriverAlias.normalize_name(name)
  DriverAlias.find_or_create_by!(normalized_name: normalized) { |a| a.driver = driver; a.name = name }
end

DriverProfile.find_or_create_by!(code: "PD1") do |p|
  p.driver = driver
  p.display_name = "Piloto Demo"
  p.color = "#e10600"
end

DriverProfile.find_or_create_by!(code: "PD2") do |p|
  p.driver = driver
  p.display_name = "P. Demo (noite)"
  p.color = "#00a8e8"
end

puts "Seeds demo ok: piloto fictício 'Piloto Demo' (perfis PD1 + PD2)."
