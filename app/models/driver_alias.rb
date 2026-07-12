class DriverAlias < ApplicationRecord
  belongs_to :driver

  validates :name, presence: true
  validates :normalized_name, presence: true, uniqueness: true

  before_validation :normalize

  def self.normalize_name(value)
    value.to_s.unicode_normalize(:nfkd).gsub(/\p{Mn}/, "").upcase.gsub(/[^A-Z ]/, " ").squeeze(" ").strip
  end

  private

  def normalize
    self.normalized_name = self.class.normalize_name(name)
  end
end
