import consumer from "./consumer"

console.log("🎯 PRICES_CHANNEL.JS WIRD GELADEN - ZÄHLER-DEBUG")
console.log("🔌 PricesChannel wird initialisiert...")
console.log("🔌 Consumer URL:", consumer.url)
console.log("🔌 Consumer Subscriptions:", consumer.subscriptions)

consumer.subscriptions.create("PricesChannel", {
  connected() {
    console.log("✅ Connected to PricesChannel")
    console.log("[->] WebSocket URL:", consumer.url)
    console.log("📡 Subscription:", this)
    console.log("📡 Subscription ID:", this.id)
  },

  disconnected() {
    console.log("❌ Disconnected from PricesChannel")
    console.log("❌ Disconnect reason:", this.disconnectReason)
  },

  rejected() {
    console.log("🚫 PricesChannel subscription rejected")
    console.log("🚫 Rejection reason:", this.rejectionReason)
  },

  received(data) {
    console.log("📨 Received update:", data)
    
    // Finde die Zeile in der Tabelle - erst nach ID, dann nach Symbol
    let row = document.querySelector(`[data-crypto-id='${data.cryptocurrency_id}']`)
    
    if (!row && data.symbol) {
      // Fallback: Suche nach Symbol in der Tabelle
      const allRows = document.querySelectorAll('tbody tr')
      const searchSymbol = data.symbol.replace('USDC', '').replace('USDT', '') // SOLUSDC -> SOL
      
      for (const tableRow of allRows) {
        const symbolCell = tableRow.querySelector('td span.badge') // Symbol-Badge
        if (symbolCell && symbolCell.textContent.trim() === searchSymbol) {
          row = tableRow
          console.log("✅ Zeile gefunden über Symbol-Matching:", data.symbol, "->", searchSymbol)
          break
        }
      }
    }
    
         if (!row) {
       console.log("[!] Row not found for crypto ID:", data.cryptocurrency_id, "Symbol:", data.symbol)
       return
     }
     
     // Debug: Zeige alle verfügbaren Zellen in der Zeile
     if (data.update_type === 'indicator' && data.indicator_type === 'rsi') {
       console.log("🔍 Debug - Alle Zellen in der Zeile:", row.innerHTML)
       const allRsiCells = row.querySelectorAll('.rsi-cell')
       console.log("🔍 Debug - Gefundene RSI-Zellen:", allRsiCells.length, allRsiCells)
     }
    
    // Behandle verschiedene Update-Typen
    if (data.update_type === 'rsi') {
      // RSI-Update (altes Format)
      console.log("📊 RSI-Update empfangen für", data.symbol, ":", data.rsi)
      const rsiCell = row.querySelector('.rsi-cell')
      if (rsiCell) {
        const rsiValue = parseFloat(data.rsi)
        rsiCell.textContent = rsiValue.toFixed(2)
        
        // RSI-Farbe basierend auf Wert
        rsiCell.className = 'rsi-cell'
        if (rsiValue >= 70) {
          rsiCell.classList.add('text-danger') // Überkauft
        } else if (rsiValue <= 30) {
          rsiCell.classList.add('text-success') // Überverkauft
        } else {
          rsiCell.classList.add('text-warning') // Neutral
        }
        
        // Animation für RSI-Update
        rsiCell.style.transition = 'background-color 0.5s'
        rsiCell.style.backgroundColor = '#fff3cd'
        setTimeout(() => {
          rsiCell.style.backgroundColor = ''
        }, 500)
        
        console.log("✅ RSI-Update completed for:", data.symbol)
      } else {
        console.log("[!] RSI cell not found for crypto ID:", data.cryptocurrency_id)
      }
         } else if (data.update_type === 'indicator' && data.indicator_type === 'rsi') {
       // RSI-Update (neues Format)
       console.log("📊 Indikator-Update empfangen für", data.symbol, ":", data.indicator_type, "=", data.value)
       
       // Suche spezifisch nach RSI-Zelle (Badge innerhalb des Links)
       const rsiCell = row.querySelector('span.rsi-cell') || row.querySelector('.rsi-cell')
       console.log("🔍 RSI-Zelle gefunden:", rsiCell)
       
       if (rsiCell) {
        const rsiValue = parseFloat(data.value)
        rsiCell.textContent = rsiValue.toFixed(2)
        
        // RSI-Farbe basierend auf Wert
        rsiCell.className = 'rsi-cell'
        if (rsiValue >= 70) {
          rsiCell.classList.add('text-danger') // Überkauft
        } else if (rsiValue <= 30) {
          rsiCell.classList.add('text-success') // Überverkauft
        } else {
          rsiCell.classList.add('text-warning') // Neutral
        }
        
        // Animation für RSI-Update
        rsiCell.style.transition = 'background-color 0.5s'
        rsiCell.style.backgroundColor = '#fff3cd'
        setTimeout(() => {
          rsiCell.style.backgroundColor = ''
        }, 500)
        
        console.log("✅ Indikator-Update completed for:", data.symbol)
      } else {
        console.log("[!] RSI cell not found for crypto ID:", data.cryptocurrency_id)
      }
    } else if (data.update_type === 'counters') {
      // Zähler-Update
      console.log("📊 Zähler-Update empfangen:", data)
      console.log("🔍 Suche nach Zähler-Elementen...")
      
      const messageCounter = document.getElementById('message-counter')
      const klineCounter = document.getElementById('kline-counter')
      const priceUpdateCounter = document.getElementById('price-update-counter')
      const rsiCalculationCounter = document.getElementById('rsi-calculation-counter')
      
      console.log("🔍 Gefundene Elemente:", {
        messageCounter: messageCounter,
        klineCounter: klineCounter,
        priceUpdateCounter: priceUpdateCounter,
        rsiCalculationCounter: rsiCalculationCounter
      })
      
      if (messageCounter) {
        messageCounter.textContent = data.message_counter || 0
        console.log("💬 Nachrichten-Zähler aktualisiert:", data.message_counter)
      } else {
        console.log("[!] message-counter Element nicht gefunden")
      }
      if (klineCounter) {
        klineCounter.textContent = data.kline_counter || 0
        console.log("📈 Klines-Zähler aktualisiert:", data.kline_counter)
      } else {
        console.log("[!] kline-counter Element nicht gefunden")
      }
      if (priceUpdateCounter) {
        priceUpdateCounter.textContent = data.price_update_counter || 0
        console.log("💰 Preis-Updates-Zähler aktualisiert:", data.price_update_counter)
      } else {
        console.log("[!] price-update-counter Element nicht gefunden")
      }
      if (rsiCalculationCounter) {
        rsiCalculationCounter.textContent = data.rsi_calculation_counter || 0
        console.log("📊 RSI-Berechnungen-Zähler aktualisiert:", data.rsi_calculation_counter)
      } else {
        console.log("[!] rsi-calculation-counter Element nicht gefunden")
      }
    } else {
      // Preis-Update (bestehende Logik)
      console.log("💰 Preis-Update empfangen für", data.symbol, ":", data.price)
      const priceCell = row.querySelector('.price-cell')
      if (priceCell) {
        const price = parseFloat(data.price)
        const formattedPrice = price >= 1 ? `$${price.toFixed(2)}` : `$${price.toFixed(6)}`
        
        // Aktualisiere den Link-Text
        const priceLink = priceCell.querySelector('a')
        if (priceLink) {
          priceLink.textContent = formattedPrice
          console.log("[->] Updated existing price link:", formattedPrice)
        } else {
          priceCell.innerHTML = `<strong><a href="/cryptocurrencies/${data.cryptocurrency_id}/chart" target="_blank" class="text-decoration-none text-primary chart-link" title="Chart anzeigen">${formattedPrice}</a></strong>`
          console.log("[->] Created new price link:", formattedPrice)
        }
        
        // Aktualisiere auch das data-sort Attribut für die Sortierung
        priceCell.closest('td').setAttribute('data-sort', price)
        
        // Füge eine kurze Animation hinzu
        priceCell.style.transition = 'background-color 0.3s'
        priceCell.style.backgroundColor = '#d4edda'
        setTimeout(() => {
          priceCell.style.backgroundColor = ''
        }, 300)
        
        console.log("✅ Price update completed for:", data.symbol)
      } else {
        console.log("[!] Price cell not found for crypto ID:", data.cryptocurrency_id)
      }
    }
  }
})

console.log("🔌 PricesChannel Setup abgeschlossen")
