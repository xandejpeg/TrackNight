class TrackAsset < ApplicationRecord
  belongs_to :track_layout
  has_one_attached :file

  KINDS = %w[svg geojson gpx glb gltf image].freeze

  validates :kind, presence: true, inclusion: { in: KINDS }
end
