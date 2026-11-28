# First-party, cookieless page view log (see PageView). Holds no IP address
# or user agent.
class CreatePageViews < ActiveRecord::Migration[8.1]
  def change
    create_table :page_views do |t|
      t.datetime :occurred_at, null: false
      t.string :path, null: false
      t.string :referrer_host
      t.string :utm_source
      t.string :utm_medium
      t.string :utm_campaign
      t.string :country, limit: 2
      t.string :device
      t.string :visitor_hash, null: false
    end
    add_index :page_views, :occurred_at
    add_index :page_views, %i[path occurred_at]
  end
end
