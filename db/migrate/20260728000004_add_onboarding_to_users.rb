class AddOnboardingToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :vehicle_preference, :integer
    add_column :users, :racing_type, :integer
    add_column :users, :onboarding_completed_at, :datetime

    create_table :user_track_layouts do |t|
      t.references :user, null: false, foreign_key: true
      t.references :track_layout, null: false, foreign_key: true
      t.timestamps
    end
    add_index :user_track_layouts, [ :user_id, :track_layout_id ], unique: true
  end
end
