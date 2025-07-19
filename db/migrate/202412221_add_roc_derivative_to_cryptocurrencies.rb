class AddRocDerivativeToCryptocurrencies < ActiveRecord::Migration[7.0]
  def change
    add_column :cryptocurrencies, :roc_derivative, :decimal, precision: 10, scale: 2
  end
end 