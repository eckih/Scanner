class DropEmptyIndicatorTables < ActiveRecord::Migration[7.1]
  def change
    # Entferne leere Historie-Tabellen
    # Diese Tabellen sind alle leer und werden nicht verwendet
    drop_table :rsi_histories
    drop_table :roc_histories
    drop_table :roc_derivative_histories
  end
end
