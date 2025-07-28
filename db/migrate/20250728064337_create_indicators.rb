class CreateIndicators < ActiveRecord::Migration[7.1]
  def change
    create_table :indicators do |t|
      t.references :cryptocurrency, null: false, foreign_key: true
      t.string :timeframe, null: false, limit: 10        # '1m', '5m', '15m', '1h', '4h'
      t.integer :period, null: false, default: 14       # RSI-Periode, MA-Periode, etc.
      t.string :indicator_type, null: false, limit: 20   # 'rsi', 'roc', 'roc_derivative', 'ma', 'ema'
      t.decimal :value, precision: 10, scale: 4, null: false
      t.datetime :calculated_at, null: false
      t.timestamps
    end
    
    # Indizes für Performance
    add_index :indicators, [:cryptocurrency_id, :timeframe]
    add_index :indicators, :indicator_type
    add_index :indicators, :calculated_at
    add_index :indicators, [:cryptocurrency_id, :timeframe, :period, :indicator_type, :calculated_at], 
              unique: true, name: 'idx_indicators_unique'
  end
end
