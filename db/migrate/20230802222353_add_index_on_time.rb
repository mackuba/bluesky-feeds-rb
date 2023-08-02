class AddIndexOnTime < ActiveRecord::Migration[6.1]
  def change
    add_index :posts, :time
  end
end
