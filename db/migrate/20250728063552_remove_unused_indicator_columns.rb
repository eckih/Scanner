class RemoveUnusedIndicatorColumns < ActiveRecord::Migration[7.1]
  def change
    # Entferne ungenutzte Indikator-Spalten aus crypto_history_data
    # Diese Spalten sind alle leer und werden nicht verwendet
    remove_column :crypto_history_data, :rsi, :decimal
    remove_column :crypto_history_data, :roc, :decimal
    remove_column :crypto_history_data, :roc_derivative, :decimal
    
    # Entferne roc_derivative aus cryptocurrencies (wird nicht verwendet)
    remove_column :cryptocurrencies, :roc_derivative, :decimal
  end
end
