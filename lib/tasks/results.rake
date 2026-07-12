namespace :results do
  desc "Importa resultados da pasta KGV_IMPORT_PATH (recurso local de desenvolvimento)"
  task import_folder: :environment do
    path = ENV["KGV_IMPORT_PATH"]
    abort "Defina KGV_IMPORT_PATH apontando para a pasta com os resultados." if path.blank?
    abort "Pasta não encontrada: #{path}" unless Dir.exist?(path)

    # Plano de perfis sugeridos por posição do arquivo (ordem alfabética).
    # Pode ser sobrescrito com KGV_PROFILE_PLAN="ACF,ACF,ACF,ACF,AC,AC,AC".
    plan = ENV.fetch("KGV_PROFILE_PLAN", "ACF,ACF,ACF,ACF,AC,AC,AC").split(",").map(&:strip)

    extensions = %w[.png .jpg .jpeg .webp .pdf]
    files = Dir.children(path).sort
                .map { |f| File.join(path, f) }
                .select { |f| File.file?(f) && extensions.include?(File.extname(f).downcase) }

    abort "Nenhum arquivo suportado encontrado em #{path}" if files.empty?

    batch = ImportBatch.create!(source: "folder", path_hint: path, started_at: Time.current)
    imported = 0
    duplicates = 0
    failures = 0

    files.each_with_index do |file, idx|
      filename = File.basename(file)
      content_type = case File.extname(file).downcase
                     when ".png" then "image/png"
                     when ".jpg", ".jpeg" then "image/jpeg"
                     when ".webp" then "image/webp"
                     when ".pdf" then "application/pdf"
                     end
      suggested = plan[idx] || plan.last

      print "→ #{filename} (sugestão de perfil: #{suggested}) ... "
      result = ResultImportService.call(
        path: file, filename:, content_type:, batch:, suggested_profile: suggested
      )
      if result.duplicate?
        duplicates += 1
        puts "duplicado (SHA-256 já importado), ignorado."
      elsif result.document.status == "failed"
        failures += 1
        puts "FALHOU: #{result.document.error_message}"
      else
        imported += 1
        puts "ok (confiança #{result.document.confidence}%, #{result.document.parsed_data['rows']&.size || 0} linhas)"
      end
    rescue => e
      failures += 1
      puts "ERRO: #{e.message}"
    end

    batch.update!(
      status: failures.zero? ? "finished" : "failed",
      finished_at: Time.current,
      stats: { imported:, duplicates:, failures:, total: files.size }
    )

    puts "\nLote ##{batch.id}: #{imported} processados, #{duplicates} duplicados, #{failures} falhas."
    puts "Acesse /imports para revisar e confirmar cada sessão." if imported.positive?
  end
end
