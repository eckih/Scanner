-- PostgreSQL Version der crypto_history_data Tabelle
-- Ausführung: docker compose exec web bundle exec bin/rails r "ActiveRecord::Base.connection.execute(File.read('db/migrate/20241223_create_crypto_history_data_manual_postgresql.sql'))"

CREATE TABLE IF NOT EXISTS crypto_history_data (
  id SERIAL PRIMARY KEY,
  cryptocurrency_id INTEGER NOT NULL,
  timestamp TIMESTAMP WITHOUT TIME ZONE NOT NULL,
  open_price DECIMAL(20,8),
  high_price DECIMAL(20,8),
  low_price DECIMAL(20,8),
  close_price DECIMAL(20,8),
  volume DECIMAL(20,8),
  rsi DECIMAL(5,2),
  roc DECIMAL(10,2),
  roc_derivative DECIMAL(10,2),
  interval VARCHAR(10) DEFAULT '1h',
  created_at TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_crypto_history_cryptocurrency 
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

-- Trigger für updated_at automatisches Update
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_crypto_history_data_updated_at 
BEFORE UPDATE ON crypto_history_data 
FOR EACH ROW EXECUTE FUNCTION update_updated_at_column(); 