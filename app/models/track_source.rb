class TrackSource < ApplicationRecord
  belongs_to :track_layout, optional: true
  belongs_to :venue, optional: true

  RELIABILITIES = %w[alta media baixa].freeze

  validates :title, presence: true
  validates :reliability, inclusion: { in: RELIABILITIES }
end
