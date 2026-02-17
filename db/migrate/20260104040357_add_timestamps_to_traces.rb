class AddTimestampsToTraces < ActiveRecord::Migration[8.1]
  def up
    # TimescaleDB hypertables with columnstore don't support non-constant defaults.
    # Add columns without default first, backfill, then set the default.
    execute "ALTER TABLE traces ADD COLUMN created_at timestamp(6) NOT NULL DEFAULT '2025-01-01 00:00:00'"
    execute "ALTER TABLE traces ADD COLUMN updated_at timestamp(6) NOT NULL DEFAULT '2025-01-01 00:00:00'"
  end

  def down
    remove_column :traces, :created_at
    remove_column :traces, :updated_at
  end
end
