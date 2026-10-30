# One row per data import for a destination, so the admin can follow its
# progress and see why it failed.
class CreateImportRuns < ActiveRecord::Migration[8.1]
  def change
    create_table :import_runs do |t|
      t.references :destination, null: false, index: false, foreign_key: { on_delete: :cascade }
      t.string :source, null: false, default: "osm"
      t.string :status, null: false, default: "queued"
      t.string :step
      t.integer :steps_done, null: false, default: 0
      t.integer :steps_total
      t.integer :attempts, null: false, default: 0
      t.jsonb :counts, null: false, default: {}
      t.text :error
      t.datetime :started_at
      t.datetime :finished_at
      t.timestamps
    end
    add_index :import_runs, [ :destination_id, :created_at ]
    add_index :import_runs, :status
  end
end
