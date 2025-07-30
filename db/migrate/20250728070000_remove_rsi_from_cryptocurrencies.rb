class RemoveRsiFromCryptocurrencies < ActiveRecord::Migration[7.1]
  def change
    remove_column :cryptocurrencies, :rsi, :decimal, precision: 5, scale: 2
  end
end 