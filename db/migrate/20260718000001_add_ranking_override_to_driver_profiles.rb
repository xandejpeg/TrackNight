class AddRankingOverrideToDriverProfiles < ActiveRecord::Migration[8.1]
  def change
    add_column :driver_profiles, :ranking_override, :string
  end
end