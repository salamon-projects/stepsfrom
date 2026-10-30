# Verified attributes of a property (waterfront today; later e.g. sea view or
# a view of a landmark). One row per property, type and subject; the subclass
# in `type` defines the categories and what the evidence holds.
class CreateVerifications < ActiveRecord::Migration[8.1]
  def change
    create_table :verifications do |t|
      t.references :property, null: false, foreign_key: { on_delete: :cascade }, index: false
      t.string :type, null: false
      # What the attribute is about when a type needs one (e.g. a landmark key)
      t.string :subject, null: false, default: ""
      t.string :category, null: false, default: "unknown"
      # Headline distance in metres (to the water, to the landmark, ...)
      t.integer :distance_m
      t.jsonb :evidence, null: false, default: {}
      t.datetime :measured_at
      t.string :qa_status, null: false, default: "pending"
      t.text :qa_note
      t.timestamps
    end
    add_index :verifications, [ :property_id, :type, :subject ], unique: true
    add_index :verifications, [ :type, :category ]
    add_index :verifications, :qa_status
  end
end
