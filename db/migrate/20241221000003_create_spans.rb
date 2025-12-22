class CreateSpans < ActiveRecord::Migration[8.0]
  def change
    create_table :spans, id: :uuid do |t|
      t.references :trace, type: :uuid, null: false, foreign_key: true
      t.references :project, type: :uuid, null: false, foreign_key: true

      t.string :span_id, null: false
      t.string :parent_span_id

      t.string :name, null: false
      t.string :kind, null: false

      t.datetime :started_at, null: false
      t.datetime :ended_at
      t.float :duration_ms

      # Details based on kind
      t.jsonb :data, default: {}

      t.boolean :error, default: false
      t.string :error_class
      t.text :error_message

      t.index [:trace_id, :started_at]
      t.index :span_id
    end
  end
end
