# frozen_string_literal: true

# Fix for Rails 8.1 compatibility with timescaledb-rails gem
# The Dimension model needs a default order to avoid MissingRequiredOrderError during schema:dump
Rails.application.config.to_prepare do
  if defined?(Timescaledb::Rails::Dimension)
    Timescaledb::Rails::Dimension.class_eval do
      self.implicit_order_column = :id if respond_to?(:implicit_order_column=)
    end
  end
end
