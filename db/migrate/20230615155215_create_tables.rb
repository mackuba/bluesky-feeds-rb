class CreateTables < ActiveRecord::Migration[6.1]
  def change
    create_table :posts do |t|
      t.string :repo, null: false
      t.datetime :time, null: false
      t.string :text, null: false
      t.text :data, null: false
      t.string :rkey, null: false
    end

    add_index :posts, :rkey

    create_table :feed_posts do |t|
      t.integer :feed_id, null: false
      t.integer :post_id, null: false
      t.datetime :time, null: false
    end

    add_index :feed_posts, [:feed_id, :time]
  end
end
