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

ActiveRecord::Schema.define(version: 2023_08_02_222353) do

  create_table "feed_posts", force: :cascade do |t|
    t.integer "feed_id", null: false
    t.integer "post_id", null: false
    t.datetime "time", null: false
    t.index ["feed_id", "time"], name: "index_feed_posts_on_feed_id_and_time"
  end

  create_table "posts", force: :cascade do |t|
    t.string "repo", null: false
    t.datetime "time", null: false
    t.string "text", null: false
    t.text "data", null: false
    t.string "rkey", null: false
    t.index ["rkey"], name: "index_posts_on_rkey"
    t.index ["time"], name: "index_posts_on_time"
  end

  create_table "subscriptions", force: :cascade do |t|
    t.string "service", null: false
    t.integer "cursor", null: false
    t.index ["service"], name: "index_subscriptions_on_service", unique: true
  end

end
