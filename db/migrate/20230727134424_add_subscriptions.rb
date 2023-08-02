class AddSubscriptions < ActiveRecord::Migration[6.1]
  def change
    create_table :subscriptions do |t|
      t.string :service, null: false
      t.integer :cursor, null: false
    end

    add_index :subscriptions, :service, unique: true
  end
end
