class Venue < ApplicationRecord
  has_many :track_layouts, dependent: :destroy
  has_many :karts, dependent: :destroy
  has_many :race_sessions, dependent: :destroy
  has_many :track_sources, dependent: :destroy

  validates :name, :slug, presence: true
  validates :slug, uniqueness: true
end
