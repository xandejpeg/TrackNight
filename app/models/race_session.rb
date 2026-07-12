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
