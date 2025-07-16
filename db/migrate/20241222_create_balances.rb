class CreateBalances < ActiveRecord::Migration[7.1]
  def change
    create_table :balances do |t|
      t.string :asset, null: false
      t.decimal :total_balance, precision: 20, scale: 8, default: 0.0
      t.decimal :free_balance, precision: 20, scale: 8, default: 0.0
      t.decimal :locked_balance, precision: 20, scale: 8, default: 0.0
      t.decimal :total_btc, precision: 20, scale: 8, default: 0.0
      t.decimal :total_usd, precision: 20, scale: 2, default: 0.0
      t.timestamps
    end
    
    add_index :balances, :asset
    add_index :balances, :created_at
    add_index :balances, [:asset, :created_at]
  end
end 