class CreateRsiHistories < ActiveRecord::Migration[7.1]
  def change
    create_table :rsi_histories do |t|
      t.references :cryptocurrency, null: false, foreign_key: true
      t.float :value, null: false
      t.string :interval, null: false, default: '1h' # z.B. '1h', '4h', '1d'
      t.datetime :calculated_at, null: false
      t.timestamps
    end
    add_index :rsi_histories, [:cryptocurrency_id, :interval, :calculated_at], unique: true, name: 'index_rsi_histories_on_crypto_interval_time'
  end
end 