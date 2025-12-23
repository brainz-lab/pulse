class AddJobFieldsToTraces < ActiveRecord::Migration[8.1]
  def change
    add_column :traces, :queue_wait_ms, :float
    add_column :traces, :executions, :integer, default: 1

    # Add index for job queue analysis
    add_index :traces, [:project_id, :queue, :started_at], name: 'idx_traces_job_queue'
  end
end
