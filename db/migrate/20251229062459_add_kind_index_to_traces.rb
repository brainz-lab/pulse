class AddKindIndexToTraces < ActiveRecord::Migration[8.1]
  def change
    # Composite index for filtering by kind and ordering by started_at
    # Covers: WHERE project_id = ? AND kind = ? ORDER BY started_at DESC
    add_index :traces, [:project_id, :kind, :started_at],
              name: 'idx_traces_project_kind_started'
  end
end
