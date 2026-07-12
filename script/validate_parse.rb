# Script de verificação do parser contra os critérios da seção 14 do escopo.
# Uso: ruby bin/rails runner script/validate_parse.rb

docs = SourceDocument.order(:filename)
puts "Documentos: #{docs.count} (esperado 7)"

docs.each do |doc|
  rows = doc.parsed_data["rows"] || []
  ale = rows.select { |r| r["matched_driver_id"].present? }
  puts "\n#{doc.filename} [#{doc.status}] conf=#{doc.confidence}% linhas=#{rows.size} tipo=#{doc.parsed_data['session_type']} nº=#{doc.parsed_data['session_number']} hora=#{doc.parsed_data['start_time_text']} layout=#{doc.parsed_data['column_layout']} perfil_sugerido=#{doc.parsed_data['suggested_profile']}"
  if ale.empty?
    puts "  !! ALESSANDRO NÃO ENCONTRADO"
    rows.each { |r| puts "    #{r['position']} #{r['name']}" }
  else
    ale.each do |r|
      puts "  ALE pos=#{r['position']} kart=#{r['kart_number']} voltas=#{r['laps']} melhor=#{r['best_lap_text']} total=#{r['total_time_text']} diff=#{r['diff_text']} gap=#{r['gap_text']} s1=#{r['s1_text']} s2=#{r['s2_text']} s3=#{r['s3_text']} spd=#{r['speed_text']} suspect=#{r['suspect']}"
    end
  end
end

# Validação global
best = ->(profile_files, field) do
  docs.select { |d| profile_files.include?(d.filename) }
      .flat_map { |d| (d.parsed_data["rows"] || []).select { |r| r["matched_driver_id"].present? } }
      .filter_map { |r| LapTime.parse_ms(r[field]) }
      .min
end

acf_files = [ "02112025 2000.jpeg", "05062026 2230.jpeg", "06062026 2200.jpeg", "09072026 1600.jpeg" ]
ac_files  = [ "10072026 1655.jpeg", "10072026 1810.jpeg", "16052026 2100.jpeg" ]
all_files = acf_files + ac_files

acf_best = best.(acf_files, "best_lap_text")
ac_best  = best.(ac_files, "best_lap_text")
s1 = best.(all_files, "s1_text")
s2 = best.(all_files, "s2_text")
s3 = best.(all_files, "s3_text")

check = ->(label, actual_ms, expected) do
  actual = actual_ms ? LapTime.format(actual_ms) : "nil"
  ok = actual == expected ? "OK" : "FALHOU (esperado #{expected})"
  puts "#{label}: #{actual} #{ok}"
end

puts "\n=== VALIDAÇÃO ==="
check.("Melhor volta ACF", acf_best, "1:02.168")
check.("Melhor volta AC", ac_best, "1:02.002")
check.("Melhor volta geral", [ acf_best, ac_best ].compact.min, "1:02.002")
check.("Melhor S1", s1, "13.951")
check.("Melhor S2", s2, "24.900")
check.("Melhor S3", s3, "22.252")
ideal = [ s1, s2, s3 ].compact.sum
check.("Volta ideal", ideal, "1:01.103")
check.("Diferença ideal→real", [ acf_best, ac_best ].compact.min - ideal, "0.899")
