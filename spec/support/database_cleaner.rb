RSpec.configure do |config|
  config.before(:suite) do
    DatabaseCleaner.strategy = :transaction
    DatabaseCleaner.clean_with(:truncation)
  end

  config.around(:each) do |example|
    # TimescaleDB hypertables (metric_points, aggregated_metrics) are incompatible
    # with the transaction strategy when compression is enabled. Use truncation for
    # specs tagged with :timescaledb.
    strategy = example.metadata[:timescaledb] ? :truncation : :transaction
    DatabaseCleaner.strategy = strategy
    DatabaseCleaner.cleaning { example.run }
  end
end
