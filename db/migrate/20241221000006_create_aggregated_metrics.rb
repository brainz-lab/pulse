class CreateAggregatedMetrics < ActiveRecord::Migration[8.0]
  def change
    create_table :aggregated_metrics, id: :uuid do |t|
      t.references :project, type: :uuid, null: false

      t.string :name, null: false
      t.datetime :bucket, null: false
      t.string :granularity, null: false

      t.float :count
      t.float :sum
      t.float :min
      t.float :max
      t.float :avg
      t.float :p50
      t.float :p95
      t.float :p99

      t.jsonb :dimensions, default: {}

      t.index [:project_id, :name, :bucket, :granularity], name: 'idx_agg_metrics_lookup'
    end
  end
end
