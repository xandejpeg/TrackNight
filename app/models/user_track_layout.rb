class UserTrackLayout < ApplicationRecord
  belongs_to :user
  belongs_to :track_layout

  validates :track_layout_id, uniqueness: { scope: :user_id }
end
