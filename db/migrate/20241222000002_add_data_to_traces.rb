class AddDataToTraces < ActiveRecord::Migration[8.1]
  def change
    add_column :traces, :data, :jsonb, default: {}, null: false unless column_exists?(:traces, :data)
  end
end
