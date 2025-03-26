class AddMissingLimits < ActiveRecord::Migration[6.1]
  def up
    change_table :posts do |t|
      t.change :repo, :string, limit: 60, null: false
      t.change :rkey, :string, limit: 16, null: false
    end
  end

  def down
    change_table :posts do |t|
      t.change :repo, :string, null: false
      t.change :rkey, :string, null: false
    end
  end
end
