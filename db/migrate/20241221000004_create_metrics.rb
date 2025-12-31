class CreateMetrics < ActiveRecord::Migration[8.0]
  def change
    create_table :metrics, id: :uuid do |t|
      t.references :project, type: :uuid, null: false, foreign_key: true

      t.string :name, null: false
      t.string :kind, null: false, default: 'gauge'
      t.string :unit
      t.text :description

      t.jsonb :tags, default: {}

      t.timestamps

      t.index [ :project_id, :name ], unique: true
    end
  end
end
