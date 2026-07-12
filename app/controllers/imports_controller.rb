class ImportsController < ApplicationController
  ROW_FIELDS = %w[position kart_number name car_class points pitstops laps
                  best_lap_text total_time_text diff_text gap_text
                  s1_text s2_text s3_text speed_text].freeze

  def index
    @pending = SourceDocument.awaiting_review.includes(file_attachment: :blob)
    @imported = SourceDocument.where(status: "imported").order(imported_at: :desc).includes(:race_session)
    @failed = SourceDocument.where(status: "failed").order(updated_at: :desc)
  end

  def new
  end

  def create
    files = Array(params[:files]).reject(&:blank?)
    return redirect_to new_import_path, alert: "Selecione pelo menos um arquivo." if files.empty?

    batch = ImportBatch.create!(source: "upload", started_at: Time.current)
    results = files.map do |file|
      ResultImportService.call(
        io: file, filename: file.original_filename,
        content_type: file.content_type, batch: batch
      )
    rescue => e
      flash[:alert] = "Falha ao processar #{file.original_filename}: #{e.message}"
      nil
    end.compact

    batch.update!(finished_at: Time.current, status: "finished",
                  stats: { processados: results.count { |r| !r.duplicate? }, duplicados: results.count(&:duplicate?) })

    dups = results.count(&:duplicate?)
    notice = "#{results.size - dups} arquivo(s) processado(s)."
    notice += " #{dups} duplicado(s) ignorado(s)." if dups.positive?
    redirect_to imports_path, notice: notice
  end

  def review
    @document = SourceDocument.find(params[:id])
    return redirect_to imports_path, alert: "Documento já importado." if @document.status == "imported"
    @parsed = @document.parsed_data.deep_symbolize_keys
    @rows = @parsed[:rows] || []
    @suggested_profile = @parsed[:suggested_profile] || suggest_profile(@document)
  end

  def confirm
    document = SourceDocument.find(params[:id])
    return redirect_to imports_path, alert: "Documento já importado." if document.status == "imported"

    rows_override = build_rows_override(document)
    date_pending = params[:date_pending] == "1"
    started_at = parse_started_at unless date_pending

    session = SessionBuilder.call(
      document,
      profile_code: params[:profile_code].presence || "ACF",
      started_at: started_at,
      date_pending: date_pending || started_at.nil?,
      rows_override: rows_override
    )
    session.update!(
      track_temp: RaceSession.track_temps.key?(params[:track_temp]) ? params[:track_temp] : nil,
      weather_condition: RaceSession.weather_conditions.key?(params[:weather_condition]) ? params[:weather_condition] : nil
    )
    redirect_to race_session_path(session), notice: "Sessão confirmada e importada."
  rescue => e
    redirect_to review_import_path(document), alert: "Erro ao confirmar: #{e.message}"
  end

  private

  def suggest_profile(document)
    date = document.suggested_session_date
    date && date.to_date >= Date.new(2026, 7, 10) ? "AC" : "ACF"
  end

  def parse_started_at
    value = params[:started_at].presence
    value ? Time.zone.parse(value) : nil
  rescue ArgumentError
    nil
  end

  # Reconstrói as linhas a partir do formulário de revisão (edições manuais).
  def build_rows_override(document)
    submitted = params[:rows]
    original = document.parsed_data.deep_symbolize_keys[:rows] || []
    return original if submitted.blank?

    original.each_with_index.map do |row, idx|
      edited = submitted[idx.to_s]
      next row unless edited
      updated = row.dup
      ROW_FIELDS.each do |field|
        next unless edited.key?(field)
        value = edited[field].presence
        value = value.to_i if value && field.in?(%w[position points laps])
        updated[field.to_sym] = value
      end
      updated[:matched_driver_id] = edited[:alessandro] == "1" ? Driver.find_by(slug: "alessandro-chiarelli")&.id : nil
      updated
    end
  end
end
