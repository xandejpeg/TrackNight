class Driver < ApplicationRecord
  has_many :driver_profiles, dependent: :destroy
  has_many :driver_aliases, dependent: :destroy
  has_many :result_entries, dependent: :nullify

  validates :name, :slug, presence: true
  validates :slug, uniqueness: true
end
