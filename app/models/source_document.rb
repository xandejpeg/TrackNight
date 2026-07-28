class SourceDocument < ApplicationRecord
  belongs_to :import_batch, optional: true
  belongs_to :user, optional: true
  has_one :race_session, dependent: :nullify
  has_one_attached :file

  STATUSES = %w[pending parsed reviewed imported failed].freeze

  validates :filename, :sha256, presence: true
  validates :sha256, uniqueness: true
  validates :status, inclusion: { in: STATUSES }

  scope :awaiting_review, -> { where(status: "parsed").order(:filename) }
  scope :processing, -> { where(status: "pending") }

  # Pendentes, travados na fila ou com falha podem ser descartados; importados não.
  def discardable?
    status.in?(%w[pending parsed failed]) && !race_session
  end

  def image?
    content_type.to_s.start_with?("image/")
  end

  def pdf?
    content_type == "application/pdf"
  end
end
