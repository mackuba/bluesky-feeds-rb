require_relative '../../app/models/post'

class AddPostsRepoIndex < ActiveRecord::Migration[6.1]
  def change
    add_index :posts, [:repo, :time]
  end
end
