class CreateServiceLevelObjectives < ActiveRecord::Migration[8.1]
  def change
    create_table :service_level_objectives, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.references :project, null: false, foreign_key: true, type: :uuid
      t.string :name, null: false
      t.text :description
      t.string :target_metric, null: false
      t.string :operator, null: false
      t.float :threshold, null: false
      t.integer :window_days, default: 30
      t.string :endpoint
      t.float :current_value
      t.float :error_budget_remaining
      t.float :burn_rate
      t.datetime :last_calculated_at
      t.boolean :enabled, default: true
      t.timestamps
    end

    add_index :service_level_objectives, [:project_id, :enabled]
  end
end
