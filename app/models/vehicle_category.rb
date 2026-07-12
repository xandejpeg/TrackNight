class VehicleCategory < ApplicationRecord
  has_many :vehicles, dependent: :destroy
  has_many :race_sessions, dependent: :destroy

  enum :vehicle_kind, { kart: 0, carro: 1, moto: 2 }

  validates :name, :slug, presence: true
  validates :slug, uniqueness: true
end
