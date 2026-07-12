# Cria a RaceSession definitiva com todas as ResultEntries a partir de um
# SourceDocument revisado. Só é chamado após confirmação na tela de revisão.
class SessionBuilder
  def self.call(document, profile_code:, started_at: nil, date_pending: false, rows_override: nil)
    new.call(document, profile_code:, started_at:, date_pending:, rows_override:)
  end

  def call(document, profile_code:, started_at:, date_pending:, rows_override:)
    parsed = document.parsed_data.deep_symbolize_keys
    profile = DriverProfile.find_by!(code: profile_code)
    venue = Venue.find_by!(slug: parsed[:venue_hint] || "kgv")
    layout = venue.track_layouts.find_by!(slug: "circuito-#{parsed[:circuit_hint] || '101'}")
    category = VehicleCategory.find_by!(slug: "kart-rental")
    source = document.pdf? ? :pdf_parse : :image_parse

    session = nil
    ActiveRecord::Base.transaction do
      session = RaceSession.create!(
        venue:, track_layout: layout, vehicle_category: category,
        source_document: document,
        driver_profile: profile,
        session_type: parsed[:session_type] || "prova",
        session_number: parsed[:session_number],
        start_time_text: parsed[:start_time_text],
        started_at: date_pending ? nil : started_at,
        date_pending: date_pending,
        review_status: :confirmada,
        data_source: source
      )

      rows = rows_override || parsed[:rows]
      original_rows = parsed[:rows]

      rows.each_with_index do |row, idx|
        row = row.symbolize_keys
        corrections = diff_corrections(original_rows[idx], row)
        driver = row[:matched_driver_id].present? ? Driver.find_by(id: row[:matched_driver_id]) : nil
        kart = row[:kart_number].present? ? Kart.find_or_create_by!(venue:, number: normalize_kart(row[:kart_number])) : nil

        session.result_entries.create!(
          position: row[:position],
          kart: kart,
          kart_number: row[:kart_number],
          transponder: row[:transponder],
          display_name: row[:name],
          driver: driver,
          driver_profile: driver ? profile : nil,
          car_class: row[:car_class],
          points: row[:points],
          pitstops: row[:pitstops],
          laps: row[:laps],
          best_lap_text: row[:best_lap_text],
          best_lap_ms: LapTime.parse_ms(row[:best_lap_text]),
          total_time_text: row[:total_time_text],
          total_time_ms: LapTime.parse_ms(row[:total_time_text]),
          diff_text: row[:diff_text],
          diff_ms: LapTime.parse_ms(row[:diff_text]),
          gap_text: row[:gap_text],
          gap_ms: LapTime.parse_ms(row[:gap_text]),
          s1_text: row[:s1_text], s1_ms: LapTime.parse_ms(row[:s1_text]),
          s2_text: row[:s2_text], s2_ms: LapTime.parse_ms(row[:s2_text]),
          s3_text: row[:s3_text], s3_ms: LapTime.parse_ms(row[:s3_text]),
          speed_text: row[:speed_text],
          speed: row[:speed_text].present? ? row[:speed_text].tr(",", ".").to_f : nil,
          raw_line: row[:raw_line],
          data_source: source,
          manual_corrections: corrections
        )
      end

      document.update!(status: "imported", imported_at: Time.current)
    end
    session
  end

  private

  def normalize_kart(number)
    number.to_s.sub(/\A0+(?=\d)/, "")
  end

  def diff_corrections(original, edited)
    return {} if original.blank?
    original = original.symbolize_keys
    edited.each_with_object({}) do |(key, value), acc|
      next if key == :matched_driver_id
      orig = original[key]
      acc[key] = { de: orig, para: value } if orig.to_s != value.to_s && original.key?(key)
    end
  end
end
