class AddWeatherToRaceSessions < ActiveRecord::Migration[8.1]
  def change
    add_column :race_sessions, :track_temp, :integer
    add_column :race_sessions, :weather_condition, :integer
  end
end
