class DriverProfile < ApplicationRecord
  belongs_to :driver
  has_many :result_entries, dependent: :nullify
  has_many :race_sessions, dependent: :nullify

  enum :kind, { main: 0, smurf: 1 }

  validates :code, :display_name, presence: true
  validates :code, uniqueness: true
  validates :ranking_override, inclusion: { in: RankingCalculator::LEVELS }, allow_blank: true
end
