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

ActiveRecord::Schema[7.1].define(version: 2025_07_28_070000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "balances", force: :cascade do |t|
    t.string "asset", null: false
    t.decimal "total_balance", precision: 20, scale: 8, default: "0.0"
    t.decimal "free_balance", precision: 20, scale: 8, default: "0.0"
    t.decimal "locked_balance", precision: 20, scale: 8, default: "0.0"
    t.decimal "total_btc", precision: 20, scale: 8, default: "0.0"
    t.decimal "total_usd", precision: 20, scale: 2, default: "0.0"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["asset", "created_at"], name: "index_balances_on_asset_and_created_at"
    t.index ["asset"], name: "index_balances_on_asset"
    t.index ["created_at"], name: "index_balances_on_created_at"
  end

  create_table "crypto_history_data", id: :serial, force: :cascade do |t|
    t.integer "cryptocurrency_id", null: false
    t.datetime "timestamp", precision: nil, null: false
    t.decimal "open_price", precision: 20, scale: 8
    t.decimal "high_price", precision: 20, scale: 8
    t.decimal "low_price", precision: 20, scale: 8
    t.decimal "close_price", precision: 20, scale: 8
    t.decimal "volume", precision: 20, scale: 8
    t.string "interval", limit: 10, default: "1h"
    t.datetime "created_at", precision: nil, default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.datetime "updated_at", precision: nil, default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.index ["cryptocurrency_id", "timestamp", "interval"], name: "index_crypto_history_on_crypto_timestamp_interval"
    t.index ["cryptocurrency_id", "timestamp", "interval"], name: "index_crypto_history_unique", unique: true
    t.index ["interval"], name: "index_crypto_history_on_interval"
    t.index ["timestamp"], name: "index_crypto_history_on_timestamp"
  end

  create_table "cryptocurrencies", force: :cascade do |t|
    t.string "symbol", null: false
    t.string "name", null: false
    t.decimal "current_price", precision: 20, scale: 8
    t.bigint "market_cap"
    t.integer "market_cap_rank"
    t.decimal "price_change_percentage_24h", precision: 10, scale: 2
    t.bigint "volume_24h"
    t.datetime "last_updated"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "price_change_24h_complete"
    t.decimal "price_change_percentage_1h", precision: 10, scale: 2
    t.decimal "price_change_percentage_30min", precision: 10, scale: 2
    t.boolean "price_change_1h_complete", default: false
    t.boolean "price_change_30min_complete", default: false
    t.index ["last_updated"], name: "index_cryptocurrencies_on_last_updated"
    t.index ["market_cap"], name: "index_cryptocurrencies_on_market_cap"
    t.index ["market_cap_rank"], name: "index_cryptocurrencies_on_market_cap_rank"
    t.index ["symbol"], name: "index_cryptocurrencies_on_symbol", unique: true
  end

  create_table "indicators", force: :cascade do |t|
    t.bigint "cryptocurrency_id", null: false
    t.string "timeframe", limit: 10, null: false
    t.integer "period", default: 14, null: false
    t.string "indicator_type", limit: 20, null: false
    t.decimal "value", precision: 10, scale: 4, null: false
    t.datetime "calculated_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["calculated_at"], name: "index_indicators_on_calculated_at"
    t.index ["cryptocurrency_id", "timeframe", "period", "indicator_type", "calculated_at"], name: "idx_indicators_unique", unique: true
    t.index ["cryptocurrency_id", "timeframe"], name: "index_indicators_on_cryptocurrency_id_and_timeframe"
    t.index ["cryptocurrency_id"], name: "index_indicators_on_cryptocurrency_id"
    t.index ["indicator_type"], name: "index_indicators_on_indicator_type"
  end

  add_foreign_key "crypto_history_data", "cryptocurrencies", name: "fk_crypto_history_cryptocurrency"
  add_foreign_key "indicators", "cryptocurrencies"
end
