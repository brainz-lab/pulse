class CreateMetricPoints < ActiveRecord::Migration[8.0]
  def change
    create_table :metric_points, id: :uuid do |t|
      t.references :project, type: :uuid, null: false
      t.references :metric, type: :uuid, null: false

      t.datetime :timestamp, null: false
      t.float :value, null: false

      t.jsonb :tags, default: {}

      t.index [ :project_id, :metric_id, :timestamp ]
    end
  end
end
