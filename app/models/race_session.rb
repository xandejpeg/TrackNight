class RaceSession < ApplicationRecord
  belongs_to :venue
  belongs_to :track_layout
  belongs_to :vehicle_category
  belongs_to :source_document, optional: true
  belongs_to :driver_profile, optional: true

  has_many :result_entries, -> { order(Arel.sql("position NULLS LAST")) }, dependent: :destroy

  enum :session_type, { treino: 0, tomada: 1, classificacao: 2, prova: 3 }
  enum :review_status, { pendente: 0, confirmada: 1 }, prefix: :review
  enum :data_source, { manual: 0, image_parse: 1, pdf_parse: 2, csv_import: 3 }, prefix: :origem

  # Condições informadas pelo piloto (opcional)
  enum :track_temp, {
    tempo_moderado: 0, frio: 1, frio_extremo: 2, calor: 3, calor_extremo: 4
  }, prefix: :temp
  enum :weather_condition, {
    clima_estavel: 0, ventania_forte: 1, chuva_fraca: 2, chuva_moderada: 3,
    chuva_forte: 4, tempestade: 5, pista_inundada: 6
  }, prefix: :clima

  TRACK_TEMP_LABELS = {
    "tempo_moderado" => "Tempo moderado", "frio" => "Frio", "frio_extremo" => "Frio extremo",
    "calor" => "Calor", "calor_extremo" => "Calor extremo"
  }.freeze
  TRACK_TEMP_ICONS = {
    "tempo_moderado" => "🌡", "frio" => "❄", "frio_extremo" => "🧊",
    "calor" => "☀", "calor_extremo" => "🔥"
  }.freeze
  WEATHER_LABELS = {
    "clima_estavel" => "Clima estável", "ventania_forte" => "Ventania forte",
    "chuva_fraca" => "Chuva fraca", "chuva_moderada" => "Chuva moderada",
    "chuva_forte" => "Chuva forte", "tempestade" => "Tempestade",
    "pista_inundada" => "Pista inundada"
  }.freeze
  WEATHER_ICONS = {
    "clima_estavel" => "🌤", "ventania_forte" => "💨", "chuva_fraca" => "🌦",
    "chuva_moderada" => "🌧", "chuva_forte" => "⛈", "tempestade" => "🌩",
    "pista_inundada" => "🌊"
  }.freeze

  scope :confirmed, -> { review_confirmada }
  scope :chronological, -> { order(Arel.sql("started_at ASC NULLS LAST, id ASC")) }
  scope :recent_first, -> { order(Arel.sql("started_at DESC NULLS LAST, id DESC")) }

  SESSION_TYPE_LABELS = {
    "treino" => "Treino", "tomada" => "Tomada", "classificacao" => "Classificação", "prova" => "Prova"
  }.freeze

  def type_label
    SESSION_TYPE_LABELS[session_type]
  end

  def title
    [ type_label, session_number ].compact.join(" ")
  end

  # Dia/noite automático pelo horário de largada: até as 17h é dia.
  def day_night
    return nil unless started_at
    started_at.hour < 17 ? "dia" : "noite"
  end

  def day? = day_night == "dia"
  def night? = day_night == "noite"

  def track_temp_label = TRACK_TEMP_LABELS[track_temp]
  def track_temp_icon = TRACK_TEMP_ICONS[track_temp]
  def weather_label = WEATHER_LABELS[weather_condition]
  def weather_icon = WEATHER_ICONS[weather_condition]

  def alessandro_entry
    result_entries.detect { |e| e.driver_id.present? }
  end

  # Melhores valores da sessão inteira (todos os participantes)
  def session_best(field)
    result_entries.filter_map(&field).min
  end

  def session_best_speed
    result_entries.filter_map(&:speed).max
  end
end
