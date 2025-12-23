class MakeAggregatedMetricsIndexUnique < ActiveRecord::Migration[8.0]
  def change
    # Remove existing non-unique index
    remove_index :aggregated_metrics, name: 'idx_agg_metrics_lookup', if_exists: true

    # Add unique index required for upsert_all
    add_index :aggregated_metrics, [:project_id, :name, :bucket, :granularity],
              name: 'idx_agg_metrics_lookup',
              unique: true
  end
end
