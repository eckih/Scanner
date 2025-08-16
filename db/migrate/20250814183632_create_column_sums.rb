class CreateColumnSums < ActiveRecord::Migration[7.1]
  def change
    create_table :column_sums do |t|
      t.decimal :sum_24h, precision: 10, scale: 2, null: false, default: 0.0
      t.decimal :sum_1h, precision: 10, scale: 2, null: false, default: 0.0
      t.decimal :sum_30min, precision: 10, scale: 2, null: false, default: 0.0
      t.integer :count_24h, null: false, default: 0
      t.integer :count_1h, null: false, default: 0
      t.integer :count_30min, null: false, default: 0
      t.datetime :calculated_at, null: false
      t.timestamps
    end
    
    # Index für schnelle Abfragen nach Zeit
    add_index :column_sums, :calculated_at
    add_index :column_sums, [:calculated_at, :sum_24h]
    add_index :column_sums, [:calculated_at, :sum_1h]
    add_index :column_sums, [:calculated_at, :sum_30min]
  end
end
