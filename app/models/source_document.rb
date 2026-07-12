class SourceDocument < ApplicationRecord
  belongs_to :import_batch, optional: true
  has_one :race_session, dependent: :nullify
  has_one_attached :file

  STATUSES = %w[pending parsed reviewed imported failed].freeze

  validates :filename, :sha256, presence: true
  validates :sha256, uniqueness: true
  validates :status, inclusion: { in: STATUSES }

  scope :awaiting_review, -> { where(status: "parsed").order(:filename) }

  def image?
    content_type.to_s.start_with?("image/")
  end

  def pdf?
    content_type == "application/pdf"
  end
end
