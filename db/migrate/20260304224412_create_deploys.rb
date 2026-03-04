class CreateDeploys < ActiveRecord::Migration[8.1]
  def change
    create_table :deploys, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.references :project, null: false, foreign_key: true, type: :uuid
      t.string :version, null: false
      t.string :commit_sha
      t.string :deployed_by
      t.string :environment
      t.text :description
      t.jsonb :metadata, default: {}
      t.datetime :deployed_at, null: false
      t.timestamps
    end

    add_index :deploys, [:project_id, :deployed_at], order: { deployed_at: :desc }
  end
end
