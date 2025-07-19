-- Manuelle Erstellung der crypto_history_data Tabelle
-- Ausführung: sqlite3 db/development.sqlite3 < db/migrate/20241223_create_crypto_history_data_manual.sql

CREATE TABLE IF NOT EXISTS crypto_history_data (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  cryptocurrency_id INTEGER NOT NULL,
  timestamp DATETIME NOT NULL,
  open_price DECIMAL(20,8),
  high_price DECIMAL(20,8),
  low_price DECIMAL(20,8),
  close_price DECIMAL(20,8),
  volume DECIMAL(20,8),
  rsi DECIMAL(5,2),
  roc DECIMAL(10,2),
  roc_derivative DECIMAL(10,2),
  interval VARCHAR(10) DEFAULT '1h',
  created_at DATETIME NOT NULL,
  updated_at DATETIME NOT NULL,
  FOREIGN KEY (cryptocurrency_id) REFERENCES cryptocurrencies(id)
);

-- Indizes für bessere Performance
CREATE INDEX IF NOT EXISTS index_crypto_history_on_crypto_timestamp_interval 
ON crypto_history_data(cryptocurrency_id, timestamp, interval);

CREATE INDEX IF NOT EXISTS index_crypto_history_on_timestamp 
ON crypto_history_data(timestamp);

CREATE INDEX IF NOT EXISTS index_crypto_history_on_interval 
ON crypto_history_data(interval);

-- Unique constraint
CREATE UNIQUE INDEX IF NOT EXISTS index_crypto_history_unique 
ON crypto_history_data(cryptocurrency_id, timestamp, interval); 