class AddPriceChange24hCompleteToCryptocurrencies < ActiveRecord::Migration[7.1]
  def change
    add_column :cryptocurrencies, :price_change_24h_complete, :boolean
  end
end
