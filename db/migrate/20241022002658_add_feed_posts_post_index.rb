class AddFeedPostsPostIndex < ActiveRecord::Migration[6.1]
  def change
    add_index :feed_posts, :post_id
  end
end
