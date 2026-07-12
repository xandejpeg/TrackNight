class ImportBatch < ApplicationRecord
  has_many :source_documents, dependent: :nullify

  STATUSES = %w[running finished failed].freeze

  validates :source, presence: true
  validates :status, inclusion: { in: STATUSES }
end
