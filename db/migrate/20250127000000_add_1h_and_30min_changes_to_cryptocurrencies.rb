class Add1hAnd30minChangesToCryptocurrencies < ActiveRecord::Migration[7.1]
  def change
    add_column :cryptocurrencies, :price_change_percentage_1h, :decimal, precision: 10, scale: 2
    add_column :cryptocurrencies, :price_change_percentage_30min, :decimal, precision: 10, scale: 2
    add_column :cryptocurrencies, :price_change_1h_complete, :boolean, default: false
    add_column :cryptocurrencies, :price_change_30min_complete, :boolean, default: false
  end
end
