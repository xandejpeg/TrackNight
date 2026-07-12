# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_07_11_225006) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "driver_aliases", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "driver_id", null: false
    t.string "name", null: false
    t.string "normalized_name", null: false
    t.datetime "updated_at", null: false
    t.index ["driver_id"], name: "index_driver_aliases_on_driver_id"
    t.index ["normalized_name"], name: "index_driver_aliases_on_normalized_name", unique: true
  end

  create_table "driver_profiles", force: :cascade do |t|
    t.string "code", null: false
    t.string "color", default: "#e10600", null: false
    t.datetime "created_at", null: false
    t.string "display_name", null: false
    t.bigint "driver_id", null: false
    t.integer "kind", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["code"], name: "index_driver_profiles_on_code", unique: true
    t.index ["driver_id"], name: "index_driver_profiles_on_driver_id"
  end

  create_table "drivers", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.string "slug", null: false
    t.datetime "updated_at", null: false
    t.index ["slug"], name: "index_drivers_on_slug", unique: true
  end

  create_table "import_batches", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "finished_at"
    t.string "path_hint"
    t.string "source", null: false
    t.datetime "started_at"
    t.jsonb "stats", default: {}, null: false
    t.string "status", default: "running", null: false
    t.datetime "updated_at", null: false
  end

  create_table "karts", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "notes"
    t.string "number", null: false
    t.datetime "updated_at", null: false
    t.bigint "venue_id", null: false
    t.index ["venue_id", "number"], name: "index_karts_on_venue_id_and_number", unique: true
    t.index ["venue_id"], name: "index_karts_on_venue_id"
  end

  create_table "race_sessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "data_source", default: 1, null: false
    t.boolean "date_pending", default: false, null: false
    t.bigint "driver_profile_id"
    t.string "label"
    t.text "notes"
    t.integer "planned_duration_minutes"
    t.integer "review_status", default: 0, null: false
    t.integer "session_number"
    t.integer "session_type", default: 3, null: false
    t.bigint "source_document_id"
    t.string "start_time_text"
    t.datetime "started_at"
    t.bigint "track_layout_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "vehicle_category_id", null: false
    t.bigint "venue_id", null: false
    t.index ["driver_profile_id"], name: "index_race_sessions_on_driver_profile_id"
    t.index ["source_document_id"], name: "index_race_sessions_on_source_document_id"
    t.index ["track_layout_id"], name: "index_race_sessions_on_track_layout_id"
    t.index ["vehicle_category_id"], name: "index_race_sessions_on_vehicle_category_id"
    t.index ["venue_id"], name: "index_race_sessions_on_venue_id"
  end

  create_table "result_entries", force: :cascade do |t|
    t.integer "best_lap_ms"
    t.string "best_lap_text"
    t.string "car_class"
    t.string "comments"
    t.datetime "created_at", null: false
    t.integer "data_source", default: 1, null: false
    t.integer "diff_ms"
    t.string "diff_text"
    t.string "display_name", null: false
    t.bigint "driver_id"
    t.bigint "driver_profile_id"
    t.integer "gap_ms"
    t.string "gap_text"
    t.bigint "kart_id"
    t.string "kart_number"
    t.integer "laps"
    t.jsonb "manual_corrections", default: {}, null: false
    t.string "pitstops"
    t.integer "points"
    t.integer "position"
    t.bigint "race_session_id", null: false
    t.text "raw_line"
    t.integer "s1_ms"
    t.string "s1_text"
    t.integer "s2_ms"
    t.string "s2_text"
    t.integer "s3_ms"
    t.string "s3_text"
    t.decimal "speed", precision: 6, scale: 1
    t.string "speed_text"
    t.bigint "total_time_ms"
    t.string "total_time_text"
    t.string "transponder"
    t.datetime "updated_at", null: false
    t.index ["driver_id"], name: "index_result_entries_on_driver_id"
    t.index ["driver_profile_id"], name: "index_result_entries_on_driver_profile_id"
    t.index ["kart_id"], name: "index_result_entries_on_kart_id"
    t.index ["race_session_id", "position"], name: "index_result_entries_on_race_session_id_and_position"
    t.index ["race_session_id"], name: "index_result_entries_on_race_session_id"
  end

  create_table "source_documents", force: :cascade do |t|
    t.bigint "byte_size"
    t.decimal "confidence", precision: 5, scale: 2
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "error_message"
    t.string "filename", null: false
    t.bigint "import_batch_id"
    t.datetime "imported_at"
    t.integer "pages"
    t.jsonb "parsed_data", default: {}, null: false
    t.string "parser_name"
    t.string "parser_version"
    t.text "raw_text"
    t.string "sha256", null: false
    t.string "status", default: "pending", null: false
    t.datetime "suggested_session_date"
    t.datetime "updated_at", null: false
    t.index ["import_batch_id"], name: "index_source_documents_on_import_batch_id"
    t.index ["sha256"], name: "index_source_documents_on_sha256", unique: true
  end

  create_table "track_assets", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "kind", null: false
    t.jsonb "metadata", default: {}, null: false
    t.text "notes"
    t.string "source_url"
    t.string "title"
    t.bigint "track_layout_id", null: false
    t.datetime "updated_at", null: false
    t.index ["track_layout_id"], name: "index_track_assets_on_track_layout_id"
  end

  create_table "track_layouts", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.integer "corners_count"
    t.datetime "created_at", null: false
    t.text "description"
    t.string "direction"
    t.jsonb "geometry", default: {}, null: false
    t.integer "length_meters"
    t.string "name", null: false
    t.string "slug", null: false
    t.string "surface"
    t.datetime "updated_at", null: false
    t.bigint "venue_id", null: false
    t.decimal "width_meters", precision: 6, scale: 2
    t.index ["venue_id", "slug"], name: "index_track_layouts_on_venue_id_and_slug", unique: true
    t.index ["venue_id"], name: "index_track_layouts_on_venue_id"
  end

  create_table "track_sectors", force: :cascade do |t|
    t.boolean "boundary_confirmed", default: false, null: false
    t.datetime "created_at", null: false
    t.text "description"
    t.string "name"
    t.integer "number", null: false
    t.bigint "track_layout_id", null: false
    t.datetime "updated_at", null: false
    t.index ["track_layout_id", "number"], name: "index_track_sectors_on_track_layout_id_and_number", unique: true
    t.index ["track_layout_id"], name: "index_track_sectors_on_track_layout_id"
  end

  create_table "track_sources", force: :cascade do |t|
    t.date "accessed_on"
    t.datetime "created_at", null: false
    t.text "notes"
    t.string "publisher"
    t.string "reliability", default: "media", null: false
    t.string "title", null: false
    t.bigint "track_layout_id"
    t.datetime "updated_at", null: false
    t.string "url"
    t.bigint "venue_id"
    t.index ["track_layout_id"], name: "index_track_sources_on_track_layout_id"
    t.index ["venue_id"], name: "index_track_sources_on_venue_id"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.boolean "must_change_password", default: false, null: false
    t.string "password_digest", null: false
    t.datetime "updated_at", null: false
    t.string "username", null: false
    t.index "lower((username)::text)", name: "index_users_on_lower_username", unique: true
  end

  create_table "vehicle_categories", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.string "slug", null: false
    t.datetime "updated_at", null: false
    t.integer "vehicle_kind", default: 0, null: false
    t.index ["slug"], name: "index_vehicle_categories_on_slug", unique: true
  end

  create_table "vehicles", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "identifier"
    t.string "name", null: false
    t.text "notes"
    t.datetime "updated_at", null: false
    t.bigint "vehicle_category_id", null: false
    t.index ["vehicle_category_id"], name: "index_vehicles_on_vehicle_category_id"
  end

  create_table "venues", force: :cascade do |t|
    t.string "address"
    t.integer "area_m2"
    t.string "city"
    t.string "country", default: "Brasil"
    t.datetime "created_at", null: false
    t.text "description"
    t.decimal "latitude", precision: 10, scale: 6
    t.decimal "longitude", precision: 10, scale: 6
    t.string "name", null: false
    t.date "opened_on"
    t.string "short_name"
    t.string "slug", null: false
    t.string "state"
    t.datetime "updated_at", null: false
    t.string "website"
    t.index ["slug"], name: "index_venues_on_slug", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "driver_aliases", "drivers"
  add_foreign_key "driver_profiles", "drivers"
  add_foreign_key "karts", "venues"
  add_foreign_key "race_sessions", "driver_profiles"
  add_foreign_key "race_sessions", "source_documents"
  add_foreign_key "race_sessions", "track_layouts"
  add_foreign_key "race_sessions", "vehicle_categories"
  add_foreign_key "race_sessions", "venues"
  add_foreign_key "result_entries", "driver_profiles"
  add_foreign_key "result_entries", "drivers"
  add_foreign_key "result_entries", "karts"
  add_foreign_key "result_entries", "race_sessions"
  add_foreign_key "source_documents", "import_batches"
  add_foreign_key "track_assets", "track_layouts"
  add_foreign_key "track_layouts", "venues"
  add_foreign_key "track_sectors", "track_layouts"
  add_foreign_key "track_sources", "track_layouts"
  add_foreign_key "track_sources", "venues"
  add_foreign_key "vehicles", "vehicle_categories"
end
