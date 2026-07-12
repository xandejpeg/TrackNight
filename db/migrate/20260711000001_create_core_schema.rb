class CreateCoreSchema < ActiveRecord::Migration[8.1]
  def change
    create_table :users do |t|
      t.string :username, null: false
      t.string :password_digest, null: false
      t.boolean :must_change_password, default: false, null: false
      t.timestamps
    end
    add_index :users, "lower(username)", unique: true, name: "index_users_on_lower_username"

    create_table :drivers do |t|
      t.string :name, null: false
      t.string :slug, null: false
      t.timestamps
    end
    add_index :drivers, :slug, unique: true

    create_table :driver_profiles do |t|
      t.references :driver, null: false, foreign_key: true
      t.string :code, null: false
      t.string :display_name, null: false
      t.integer :kind, default: 0, null: false
      t.string :color, default: "#e10600", null: false
      t.timestamps
    end
    add_index :driver_profiles, :code, unique: true

    create_table :driver_aliases do |t|
      t.references :driver, null: false, foreign_key: true
      t.string :name, null: false
      t.string :normalized_name, null: false
      t.timestamps
    end
    add_index :driver_aliases, :normalized_name, unique: true

    create_table :venues do |t|
      t.string :name, null: false
      t.string :slug, null: false
      t.string :short_name
      t.string :address
      t.string :city
      t.string :state
      t.string :country, default: "Brasil"
      t.decimal :latitude, precision: 10, scale: 6
      t.decimal :longitude, precision: 10, scale: 6
      t.string :website
      t.text :description
      t.integer :area_m2
      t.date :opened_on
      t.timestamps
    end
    add_index :venues, :slug, unique: true

    create_table :track_layouts do |t|
      t.references :venue, null: false, foreign_key: true
      t.string :name, null: false
      t.string :slug, null: false
      t.integer :length_meters
      t.decimal :width_meters, precision: 6, scale: 2
      t.integer :corners_count
      t.string :direction
      t.string :surface
      t.text :description
      t.jsonb :geometry, default: {}, null: false
      t.boolean :active, default: true, null: false
      t.timestamps
    end
    add_index :track_layouts, [ :venue_id, :slug ], unique: true

    create_table :track_sectors do |t|
      t.references :track_layout, null: false, foreign_key: true
      t.integer :number, null: false
      t.string :name
      t.text :description
      t.boolean :boundary_confirmed, default: false, null: false
      t.timestamps
    end
    add_index :track_sectors, [ :track_layout_id, :number ], unique: true

    create_table :track_assets do |t|
      t.references :track_layout, null: false, foreign_key: true
      t.string :kind, null: false
      t.string :title
      t.string :source_url
      t.text :notes
      t.jsonb :metadata, default: {}, null: false
      t.timestamps
    end

    create_table :track_sources do |t|
      t.references :track_layout, foreign_key: true
      t.references :venue, foreign_key: true
      t.string :title, null: false
      t.string :url
      t.string :publisher
      t.date :accessed_on
      t.string :reliability, default: "media", null: false
      t.text :notes
      t.timestamps
    end

    create_table :vehicle_categories do |t|
      t.string :name, null: false
      t.string :slug, null: false
      t.integer :vehicle_kind, default: 0, null: false
      t.timestamps
    end
    add_index :vehicle_categories, :slug, unique: true

    create_table :vehicles do |t|
      t.references :vehicle_category, null: false, foreign_key: true
      t.string :name, null: false
      t.string :identifier
      t.text :notes
      t.timestamps
    end

    create_table :karts do |t|
      t.references :venue, null: false, foreign_key: true
      t.string :number, null: false
      t.text :notes
      t.timestamps
    end
    add_index :karts, [ :venue_id, :number ], unique: true

    create_table :import_batches do |t|
      t.string :source, null: false
      t.string :path_hint
      t.string :status, default: "running", null: false
      t.jsonb :stats, default: {}, null: false
      t.datetime :started_at
      t.datetime :finished_at
      t.timestamps
    end

    create_table :source_documents do |t|
      t.references :import_batch, foreign_key: true
      t.string :filename, null: false
      t.string :sha256, null: false
      t.string :content_type
      t.bigint :byte_size
      t.integer :pages
      t.string :parser_name
      t.string :parser_version
      t.text :raw_text
      t.decimal :confidence, precision: 5, scale: 2
      t.string :status, default: "pending", null: false
      t.jsonb :parsed_data, default: {}, null: false
      t.datetime :suggested_session_date
      t.string :error_message
      t.datetime :imported_at
      t.timestamps
    end
    add_index :source_documents, :sha256, unique: true

    create_table :race_sessions do |t|
      t.references :venue, null: false, foreign_key: true
      t.references :track_layout, null: false, foreign_key: true
      t.references :vehicle_category, null: false, foreign_key: true
      t.references :source_document, foreign_key: true
      t.references :driver_profile, foreign_key: true
      t.integer :session_type, default: 3, null: false
      t.integer :session_number
      t.string :label
      t.datetime :started_at
      t.boolean :date_pending, default: false, null: false
      t.string :start_time_text
      t.integer :planned_duration_minutes
      t.integer :review_status, default: 0, null: false
      t.integer :data_source, default: 1, null: false
      t.text :notes
      t.timestamps
    end

    create_table :result_entries do |t|
      t.references :race_session, null: false, foreign_key: true
      t.references :kart, foreign_key: true
      t.references :driver, foreign_key: true
      t.references :driver_profile, foreign_key: true
      t.integer :position
      t.string :kart_number
      t.string :transponder
      t.string :display_name, null: false
      t.string :car_class
      t.string :comments
      t.integer :points
      t.string :pitstops
      t.integer :laps
      t.integer :best_lap_ms
      t.string :best_lap_text
      t.bigint :total_time_ms
      t.string :total_time_text
      t.integer :diff_ms
      t.string :diff_text
      t.integer :gap_ms
      t.string :gap_text
      t.integer :s1_ms
      t.string :s1_text
      t.integer :s2_ms
      t.string :s2_text
      t.integer :s3_ms
      t.string :s3_text
      t.decimal :speed, precision: 6, scale: 1
      t.string :speed_text
      t.text :raw_line
      t.integer :data_source, default: 1, null: false
      t.jsonb :manual_corrections, default: {}, null: false
      t.timestamps
    end
    add_index :result_entries, [ :race_session_id, :position ]
  end
end
