class TrackSector < ApplicationRecord
  belongs_to :track_layout

  validates :number, presence: true, uniqueness: { scope: :track_layout_id }
end
