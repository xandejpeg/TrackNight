class TrackLayout < ApplicationRecord
  belongs_to :venue
  has_many :track_sectors, -> { order(:number) }, dependent: :destroy
  has_many :track_assets, dependent: :destroy
  has_many :track_sources, dependent: :destroy
  has_many :race_sessions, dependent: :destroy

  validates :name, :slug, presence: true
  validates :slug, uniqueness: { scope: :venue_id }
end
