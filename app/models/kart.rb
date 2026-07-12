class Kart < ApplicationRecord
  belongs_to :venue
  has_many :result_entries, dependent: :nullify

  validates :number, presence: true, uniqueness: { scope: :venue_id }
end
