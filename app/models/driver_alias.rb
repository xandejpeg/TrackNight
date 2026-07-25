class DriverAlias < ApplicationRecord
  belongs_to :driver

  validates :name, presence: true
  validates :normalized_name, presence: true, uniqueness: true

  before_validation :normalize

  def self.normalize_name(value) = ParticipantName.normalize(value)

  private

  def normalize
    self.normalized_name = self.class.normalize_name(name)
  end
end
