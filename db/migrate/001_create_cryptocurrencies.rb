class CreateCryptocurrencies < ActiveRecord::Migration[7.0]
  def change
    create_table :cryptocurrencies do |t|
      t.string :symbol, null: false
      t.string :name, null: false
      t.decimal :current_price, precision: 20, scale: 8
      t.bigint :market_cap
      t.integer :market_cap_rank
      t.decimal :price_change_percentage_24h, precision: 10, scale: 2
      t.bigint :volume_24h
      t.decimal :rsi, precision: 5, scale: 2
      t.datetime :last_updated
      
      t.timestamps
    end
    
    add_index :cryptocurrencies, :symbol, unique: true
    add_index :cryptocurrencies, :market_cap_rank
    add_index :cryptocurrencies, :market_cap
    add_index :cryptocurrencies, :last_updated
  end
end 