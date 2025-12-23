class AddSettingsToProjects < ActiveRecord::Migration[8.1]
  def change
    add_column :projects, :settings, :jsonb, default: {}, null: false unless column_exists?(:projects, :settings)
  end
end
