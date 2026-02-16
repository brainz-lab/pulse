class CreateSolidCacheTables < ActiveRecord::Migration[7.1]
  def change
    create_table :solid_cache_entries do |t|
      t.binary :key, null: false
      t.binary :value, null: false
      t.datetime :created_at, null: false
      t.bigint :key_hash, null: false
      t.integer :byte_size, null: false

      t.index [:key_hash], unique: true
      t.index [:key_hash, :byte_size]
      t.index [:byte_size]
    end
  end
end