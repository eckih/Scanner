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

ActiveRecord::Schema[7.1].define(version: 1) do
  create_table "cryptocurrencies", force: :cascade do |t|
    t.string "symbol", null: false
    t.string "name", null: false
    t.decimal "current_price", precision: 20, scale: 8
    t.bigint "market_cap"
    t.integer "market_cap_rank"
    t.decimal "price_change_percentage_24h", precision: 10, scale: 2
    t.bigint "volume_24h"
    t.decimal "rsi", precision: 5, scale: 2
    t.datetime "last_updated"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["last_updated"], name: "index_cryptocurrencies_on_last_updated"
    t.index ["market_cap"], name: "index_cryptocurrencies_on_market_cap"
    t.index ["market_cap_rank"], name: "index_cryptocurrencies_on_market_cap_rank"
    t.index ["symbol"], name: "index_cryptocurrencies_on_symbol", unique: true
  end

end
