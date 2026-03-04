class CreateSavedViews < ActiveRecord::Migration[8.1]
  def change
    create_table :saved_views, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.references :project, null: false, foreign_key: true, type: :uuid
      t.string :name, null: false
      t.string :view_type, null: false
      t.jsonb :filters, default: {}
      t.boolean :pinned, default: false
      t.timestamps
    end

    add_index :saved_views, [:project_id, :view_type]
  end
end
