class CreateProjects < ActiveRecord::Migration[8.0]
  def change
    enable_extension 'pgcrypto' unless extension_enabled?('pgcrypto')

    create_table :projects, id: :uuid do |t|
      t.string :platform_project_id, null: false
      t.string :name
      t.string :environment, default: 'live'

      # Apdex configuration
      t.float :apdex_t, default: 0.5  # Satisfying threshold in seconds

      t.timestamps

      t.index :platform_project_id, unique: true
    end
  end
end
