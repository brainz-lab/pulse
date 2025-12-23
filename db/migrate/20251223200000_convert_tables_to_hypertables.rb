class ConvertTablesToHypertables < ActiveRecord::Migration[8.0]
  def up
    # TimescaleDB requires the time column to be part of any unique index/primary key
    # We need to handle foreign key constraints first

    # ========== TRACES ==========
    # Drop foreign key from spans first
    execute "ALTER TABLE spans DROP CONSTRAINT IF EXISTS fk_rails_9fb60f666f;"

    execute "ALTER TABLE traces DROP CONSTRAINT traces_pkey;"
    execute "ALTER TABLE traces ADD PRIMARY KEY (id, started_at);"

    # Drop unique index on trace_id (needs to include time column)
    execute "DROP INDEX IF EXISTS index_traces_on_trace_id;"
    execute "CREATE UNIQUE INDEX index_traces_on_trace_id ON traces (trace_id, started_at);"

    execute <<-SQL
      SELECT create_hypertable(
        'traces',
        'started_at',
        chunk_time_interval => INTERVAL '1 hour',
        migrate_data => true,
        if_not_exists => true
      );
    SQL

    execute <<-SQL
      ALTER TABLE traces SET (
        timescaledb.compress,
        timescaledb.compress_segmentby = 'project_id',
        timescaledb.compress_orderby = 'started_at DESC'
      );
    SQL
    execute "SELECT add_compression_policy('traces', INTERVAL '7 days', if_not_exists => true);"
    execute "SELECT add_retention_policy('traces', INTERVAL '30 days', if_not_exists => true);"

    # ========== SPANS ==========
    execute "ALTER TABLE spans DROP CONSTRAINT spans_pkey;"
    execute "ALTER TABLE spans ADD PRIMARY KEY (id, started_at);"

    execute <<-SQL
      SELECT create_hypertable(
        'spans',
        'started_at',
        chunk_time_interval => INTERVAL '1 hour',
        migrate_data => true,
        if_not_exists => true
      );
    SQL

    execute <<-SQL
      ALTER TABLE spans SET (
        timescaledb.compress,
        timescaledb.compress_segmentby = 'project_id, trace_id',
        timescaledb.compress_orderby = 'started_at DESC'
      );
    SQL
    execute "SELECT add_compression_policy('spans', INTERVAL '7 days', if_not_exists => true);"
    execute "SELECT add_retention_policy('spans', INTERVAL '30 days', if_not_exists => true);"

    # ========== METRIC_POINTS ==========
    execute "ALTER TABLE metric_points DROP CONSTRAINT metric_points_pkey;"
    execute "ALTER TABLE metric_points ADD PRIMARY KEY (id, timestamp);"

    execute <<-SQL
      SELECT create_hypertable(
        'metric_points',
        'timestamp',
        chunk_time_interval => INTERVAL '1 hour',
        migrate_data => true,
        if_not_exists => true
      );
    SQL

    execute <<-SQL
      ALTER TABLE metric_points SET (
        timescaledb.compress,
        timescaledb.compress_segmentby = 'project_id, metric_id',
        timescaledb.compress_orderby = 'timestamp DESC'
      );
    SQL
    execute "SELECT add_compression_policy('metric_points', INTERVAL '7 days', if_not_exists => true);"
    execute "SELECT add_retention_policy('metric_points', INTERVAL '90 days', if_not_exists => true);"
  end

  def down
    execute "SELECT remove_retention_policy('traces', if_exists => true);"
    execute "SELECT remove_retention_policy('spans', if_exists => true);"
    execute "SELECT remove_retention_policy('metric_points', if_exists => true);"

    execute "SELECT remove_compression_policy('traces', if_exists => true);"
    execute "SELECT remove_compression_policy('spans', if_exists => true);"
    execute "SELECT remove_compression_policy('metric_points', if_exists => true);"

    execute "ALTER TABLE traces SET (timescaledb.compress = false);"
    execute "ALTER TABLE spans SET (timescaledb.compress = false);"
    execute "ALTER TABLE metric_points SET (timescaledb.compress = false);"
  end
end
