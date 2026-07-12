class Vehicle < ApplicationRecord
  belongs_to :vehicle_category

  validates :name, presence: true
end
