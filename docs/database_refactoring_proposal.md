# [REFRESH] Datenbank-Refaktorierung Vorschlag

## 🎯 Ziel
Eliminierung von Datenredundanz und Vereinfachung der Datenbankstruktur

## ❌ Aktuelle Probleme

### Redundante Datenspeicherung:
- **RSI**: 3 Tabellen (`cryptocurrencies`, `crypto_history_data`, `rsi_histories`)
- **ROC**: 2 Tabellen (`crypto_history_data`, `roc_histories`) 
- **ROC Derivative**: 3 Tabellen (`cryptocurrencies`, `crypto_history_data`, `roc_derivative_histories`)

### Performance-Probleme:
- Unnötige Duplikate verlangsamen Queries
- Komplexe Synchronisation zwischen Tabellen
- Höherer Speicherverbrauch

## ✅ Neue Struktur

### 1. Haupttabellen (unverändert)
```sql
-- cryptocurrencies: Nur aktuelle Werte für schnelle Anzeige
CREATE TABLE cryptocurrencies (
  id BIGSERIAL PRIMARY KEY,
  symbol VARCHAR NOT NULL UNIQUE,
  name VARCHAR NOT NULL,
  current_price DECIMAL(20,8),
  market_cap BIGINT,
  market_cap_rank INTEGER,
  price_change_percentage_24h DECIMAL(10,2),
  volume_24h BIGINT,
  last_updated TIMESTAMP,
  price_change_24h_complete BOOLEAN,
  created_at TIMESTAMP NOT NULL,
  updated_at TIMESTAMP NOT NULL
);

-- crypto_history_data: Nur OHLCV-Daten (Kerzen)
CREATE TABLE crypto_history_data (
  id SERIAL PRIMARY KEY,
  cryptocurrency_id INTEGER NOT NULL,
  timestamp TIMESTAMP NOT NULL,
  open_price DECIMAL(20,8),
  high_price DECIMAL(20,8),
  low_price DECIMAL(20,8),
  close_price DECIMAL(20,8),
  volume DECIMAL(20,8),
  interval VARCHAR(10) DEFAULT '1h',
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE(cryptocurrency_id, timestamp, interval)
);
```

### 2. Neue einheitliche Indikator-Tabelle
```sql
-- indicators: Alle technischen Indikatoren in einer Tabelle
CREATE TABLE indicators (
  id BIGSERIAL PRIMARY KEY,
  cryptocurrency_id BIGINT NOT NULL,
  timeframe VARCHAR(10) NOT NULL,        -- '1m', '5m', '15m', '1h', '4h'
  period INTEGER NOT NULL DEFAULT 14,    -- RSI-Periode, MA-Periode, etc.
  indicator_type VARCHAR(20) NOT NULL,   -- 'rsi', 'roc', 'roc_derivative', 'ma', 'ema'
  value DECIMAL(10,4) NOT NULL,
  calculated_at TIMESTAMP NOT NULL,
  created_at TIMESTAMP NOT NULL,
  updated_at TIMESTAMP NOT NULL,
  
  UNIQUE(cryptocurrency_id, timeframe, period, indicator_type, calculated_at),
  FOREIGN KEY (cryptocurrency_id) REFERENCES cryptocurrencies(id)
);

-- Indizes für Performance
CREATE INDEX idx_indicators_crypto_timeframe ON indicators(cryptocurrency_id, timeframe);
CREATE INDEX idx_indicators_type ON indicators(indicator_type);
CREATE INDEX idx_indicators_calculated_at ON indicators(calculated_at);
```

## [REFRESH] Migration Plan

### Phase 1: Neue Tabelle erstellen
```ruby
class CreateIndicators < ActiveRecord::Migration[7.1]
  def change
    create_table :indicators do |t|
      t.references :cryptocurrency, null: false, foreign_key: true
      t.string :timeframe, null: false, limit: 10
      t.integer :period, null: false, default: 14
      t.string :indicator_type, null: false, limit: 20
      t.decimal :value, precision: 10, scale: 4, null: false
      t.datetime :calculated_at, null: false
      t.timestamps
    end
    
    add_index :indicators, [:cryptocurrency_id, :timeframe]
    add_index :indicators, :indicator_type
    add_index :indicators, :calculated_at
    add_index :indicators, [:cryptocurrency_id, :timeframe, :period, :indicator_type, :calculated_at], 
              unique: true, name: 'idx_indicators_unique'
  end
end
```

### Phase 2: Daten migrieren
```ruby
class MigrateIndicatorsData < ActiveRecord::Migration[7.1]
  def up
    # RSI-Daten migrieren
    RsiHistory.find_each do |rsi|
      Indicator.create!(
        cryptocurrency_id: rsi.cryptocurrency_id,
        timeframe: rsi.interval,
        period: 14,
        indicator_type: 'rsi',
        value: rsi.value,
        calculated_at: rsi.calculated_at
      )
    end
    
    # ROC-Daten migrieren
    RocHistory.find_each do |roc|
      Indicator.create!(
        cryptocurrency_id: roc.cryptocurrency_id,
        timeframe: roc.interval,
        period: 14,
        indicator_type: 'roc',
        value: roc.value,
        calculated_at: roc.calculated_at
      )
    end
    
    # ROC Derivative-Daten migrieren
    RocDerivativeHistory.find_each do |roc_der|
      Indicator.create!(
        cryptocurrency_id: roc_der.cryptocurrency_id,
        timeframe: roc_der.interval,
        period: 14,
        indicator_type: 'roc_derivative',
        value: roc_der.value,
        calculated_at: roc_der.calculated_at
      )
    end
  end
end
```

### Phase 3: Spalten aus crypto_history_data entfernen
```ruby
class RemoveIndicatorsFromCryptoHistoryData < ActiveRecord::Migration[7.1]
  def change
    remove_column :crypto_history_data, :rsi, :decimal
    remove_column :crypto_history_data, :roc, :decimal
    remove_column :crypto_history_data, :roc_derivative, :decimal
  end
end
```

### Phase 4: Alte Tabellen entfernen
```ruby
class DropOldIndicatorTables < ActiveRecord::Migration[7.1]
  def change
    drop_table :rsi_histories
    drop_table :roc_histories  
    drop_table :roc_derivative_histories
  end
end
```

### Phase 5: Spalten aus cryptocurrencies bereinigen
```ruby
class CleanupCryptocurrenciesTable < ActiveRecord::Migration[7.1]
  def change
    # Behalte nur den aktuellen RSI für schnelle Anzeige
    # Entferne roc_derivative (kann aus indicators geholt werden)
    remove_column :cryptocurrencies, :roc_derivative, :decimal
  end
end
```

## 📊 Neue Modelle

### Indicator Model
```ruby
class Indicator < ApplicationRecord
  belongs_to :cryptocurrency
  
  validates :timeframe, presence: true, inclusion: { in: %w[1m 5m 15m 1h 4h 1d] }
  validates :indicator_type, presence: true, inclusion: { in: %w[rsi roc roc_derivative ma ema] }
  validates :period, presence: true, numericality: { greater_than: 0 }
  validates :value, presence: true
  
  scope :rsi, -> { where(indicator_type: 'rsi') }
  scope :roc, -> { where(indicator_type: 'roc') }
  scope :roc_derivative, -> { where(indicator_type: 'roc_derivative') }
  scope :for_timeframe, ->(tf) { where(timeframe: tf) }
  scope :for_period, ->(p) { where(period: p) }
  scope :latest, -> { order(calculated_at: :desc) }
  
  def self.latest_rsi(crypto_id, timeframe, period = 14)
    rsi.where(cryptocurrency_id: crypto_id, timeframe: timeframe, period: period).latest.first
  end
  
  def self.latest_roc(crypto_id, timeframe, period = 14)
    roc.where(cryptocurrency_id: crypto_id, timeframe: timeframe, period: period).latest.first
  end
end
```

### Erweiterte Cryptocurrency Model
```ruby
class Cryptocurrency < ApplicationRecord
  has_many :crypto_history_data, dependent: :destroy
  has_many :indicators, dependent: :destroy
  
  # Convenience methods für aktuelle Indikatoren
  def current_rsi(timeframe = '15m', period = 14)
    indicators.rsi.for_timeframe(timeframe).for_period(period).latest.first&.value || rsi
  end
  
  def current_roc(timeframe = '15m', period = 14)
    indicators.roc.for_timeframe(timeframe).for_period(period).latest.first&.value
  end
  
  def current_roc_derivative(timeframe = '15m', period = 14)
    indicators.roc_derivative.for_timeframe(timeframe).for_period(period).latest.first&.value
  end
end
```

## 🚀 Vorteile der neuen Struktur

### ✅ Eliminierte Redundanz
- **1 Tabelle** statt 3 für alle Indikatoren
- **Keine Duplikate** mehr zwischen Tabellen
- **Konsistente Datenstruktur**

### ✅ Erweiterbarkeit
- Neue Indikatoren (MA, EMA, MACD) einfach hinzufügbar
- Verschiedene Perioden pro Indikator
- Flexible Timeframe-Unterstützung

### ✅ Performance
- **Weniger Joins** bei Queries
- **Kleinere Datenbank** durch weniger Duplikate
- **Bessere Indizierung** möglich

### ✅ Wartbarkeit
- **Ein Service** für alle Indikatoren
- **Einheitliche API** für Frontend
- **Einfachere Tests**

## 📈 Beispiel-Queries

```ruby
# Aktueller RSI für BTC/USDC, 15m, Periode 14
btc = Cryptocurrency.find_by(symbol: 'BTC/USDC')
current_rsi = btc.indicators.rsi.for_timeframe('15m').for_period(14).latest.first

# RSI-Historie der letzten 24 Stunden
rsi_history = btc.indicators.rsi.for_timeframe('15m')
                 .where(calculated_at: 24.hours.ago..Time.current)
                 .order(:calculated_at)

# Alle Indikatoren für einen Zeitpunkt
all_indicators = btc.indicators.where(
  timeframe: '15m', 
  calculated_at: Time.current.beginning_of_hour
)
```

## 🔧 Migration Ausführung

```bash
# 1. Neue Tabelle erstellen
docker compose exec web bin/rails generate migration CreateIndicators
docker compose exec web bin/rails db:migrate

# 2. Daten migrieren
docker compose exec web bin/rails generate migration MigrateIndicatorsData  
docker compose exec web bin/rails db:migrate

# 3. Alte Strukturen bereinigen
docker compose exec web bin/rails generate migration CleanupOldIndicatorStructure
docker compose exec web bin/rails db:migrate
```

## 📊 Speicherplatz-Einsparung

**Vorher:**
- 3 separate Indikator-Tabellen
- RSI/ROC/ROC_Derivative in crypto_history_data
- Geschätzt: ~70% Redundanz

**Nachher:**
- 1 einheitliche Indikator-Tabelle
- Nur OHLCV in crypto_history_data
- Geschätzt: ~50% weniger Speicherverbrauch 