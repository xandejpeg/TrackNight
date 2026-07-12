class ResultEntry < ApplicationRecord
  belongs_to :race_session
  belongs_to :kart, optional: true
  belongs_to :driver, optional: true
  belongs_to :driver_profile, optional: true

  enum :data_source, { manual: 0, image_parse: 1, pdf_parse: 2, csv_import: 3 }, prefix: :origem

  validates :display_name, presence: true

  scope :of_driver, -> { where.not(driver_id: nil) }

  def alessandro?
    driver_id.present?
  end

  def ideal_lap_ms
    return nil unless s1_ms && s2_ms && s3_ms
    s1_ms + s2_ms + s3_ms
  end
end
