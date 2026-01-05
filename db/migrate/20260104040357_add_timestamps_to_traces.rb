class AddTimestampsToTraces < ActiveRecord::Migration[8.1]
  def change
    add_column :traces, :created_at, :datetime, null: false, default: -> { 'CURRENT_TIMESTAMP' }
    add_column :traces, :updated_at, :datetime, null: false, default: -> { 'CURRENT_TIMESTAMP' }
  end
end
