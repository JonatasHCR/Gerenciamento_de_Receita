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

ActiveRecord::Schema[8.1].define(version: 2026_06_05_135229) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "pg_trgm"

  create_table "adjustments", force: :cascade do |t|
    t.bigint "cost_center_id", null: false
    t.datetime "created_at", null: false
    t.integer "kind", null: false
    t.date "new_date"
    t.decimal "new_value", precision: 15, scale: 2
    t.text "note"
    t.date "previous_date"
    t.decimal "previous_value", precision: 15, scale: 2
    t.datetime "updated_at", null: false
    t.index ["cost_center_id"], name: "index_adjustments_on_cost_center_id"
  end

  create_table "clients", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "full_name", default: "", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_clients_on_name", unique: true
  end

  create_table "cost_centers", force: :cascade do |t|
    t.bigint "client_id", null: false
    t.string "contract_number"
    t.string "coordinator"
    t.string "cr_code", null: false
    t.datetime "created_at", null: false
    t.string "description", default: "", null: false
    t.date "end_date"
    t.text "object_text"
    t.decimal "participation", precision: 5, scale: 4, default: "1.0"
    t.date "start_date"
    t.datetime "updated_at", null: false
    t.decimal "value", precision: 15, scale: 2, default: "0.0"
    t.index ["client_id"], name: "index_cost_centers_on_client_id"
    t.index ["coordinator"], name: "idx_cost_centers_coordinator_trgm", opclass: :gin_trgm_ops, using: :gin
    t.index ["cr_code"], name: "idx_cost_centers_cr_code_trgm", opclass: :gin_trgm_ops, using: :gin
    t.index ["cr_code"], name: "index_cost_centers_on_cr_code", unique: true
    t.index ["description"], name: "idx_cost_centers_description_trgm", opclass: :gin_trgm_ops, using: :gin
  end

  create_table "forecast_entries", force: :cascade do |t|
    t.bigint "cost_center_id", null: false
    t.datetime "created_at", null: false
    t.decimal "forecasted_total", precision: 15, scale: 2, default: "0.0"
    t.string "month_year", null: false
    t.text "observations"
    t.datetime "updated_at", null: false
    t.index ["cost_center_id", "month_year"], name: "index_forecast_entries_on_cost_center_id_and_month_year", unique: true
    t.index ["cost_center_id"], name: "index_forecast_entries_on_cost_center_id"
    t.index ["month_year"], name: "index_forecast_entries_on_month_year"
  end

  create_table "invoices", force: :cascade do |t|
    t.string "client_name", default: "", null: false
    t.bigint "cost_center_id", null: false
    t.datetime "created_at", null: false
    t.date "issued_at", null: false
    t.integer "kind", default: 0, null: false
    t.string "number", null: false
    t.text "observations"
    t.datetime "updated_at", null: false
    t.decimal "value", precision: 15, scale: 2, null: false
    t.index ["cost_center_id", "number"], name: "index_invoices_on_cost_center_id_and_number", unique: true
    t.index ["cost_center_id"], name: "index_invoices_on_cost_center_id"
    t.index ["issued_at", "cost_center_id"], name: "index_invoices_on_issued_at_and_cost_center_id"
    t.index ["issued_at"], name: "index_invoices_on_issued_at"
    t.index ["kind"], name: "index_invoices_on_kind"
    t.index ["number"], name: "idx_invoices_number_trgm", opclass: :gin_trgm_ops, using: :gin
  end

  create_table "receipts", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "invoice_id", null: false
    t.text "observations"
    t.date "payment_date", null: false
    t.datetime "updated_at", null: false
    t.decimal "value", precision: 15, scale: 2, null: false
    t.index ["invoice_id", "value"], name: "index_receipts_on_invoice_id_and_value"
    t.index ["invoice_id"], name: "index_receipts_on_invoice_id"
    t.index ["payment_date"], name: "index_receipts_on_payment_date"
  end

  create_table "user_cost_centers", force: :cascade do |t|
    t.bigint "cost_center_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["cost_center_id"], name: "index_user_cost_centers_on_cost_center_id"
    t.index ["user_id", "cost_center_id"], name: "index_user_cost_centers_on_user_id_and_cost_center_id", unique: true
    t.index ["user_id"], name: "index_user_cost_centers_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.integer "failed_attempts", default: 0, null: false
    t.datetime "locked_at"
    t.string "name", default: "", null: false
    t.datetime "remember_created_at"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.integer "role", default: 0, null: false
    t.string "unlock_token"
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["role"], name: "index_users_on_role"
    t.index ["unlock_token"], name: "index_users_on_unlock_token", unique: true
  end

  create_table "versions", force: :cascade do |t|
    t.datetime "created_at"
    t.string "event", null: false
    t.bigint "item_id", null: false
    t.string "item_type", null: false
    t.jsonb "object"
    t.jsonb "object_changes"
    t.string "whodunnit"
    t.index ["created_at"], name: "index_versions_on_created_at"
    t.index ["event"], name: "index_versions_on_event"
    t.index ["item_type", "item_id"], name: "index_versions_on_item_type_and_item_id"
    t.index ["whodunnit"], name: "index_versions_on_whodunnit"
  end

  add_foreign_key "adjustments", "cost_centers"
  add_foreign_key "cost_centers", "clients"
  add_foreign_key "forecast_entries", "cost_centers"
  add_foreign_key "invoices", "cost_centers"
  add_foreign_key "receipts", "invoices"
  add_foreign_key "user_cost_centers", "cost_centers"
  add_foreign_key "user_cost_centers", "users"
end
