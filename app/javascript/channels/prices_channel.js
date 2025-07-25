import consumer from "./consumer"

console.log("🔌 PricesChannel wird initialisiert...")
console.log("🔌 Consumer URL:", consumer.url)
console.log("🔌 Consumer Subscriptions:", consumer.subscriptions)

consumer.subscriptions.create("PricesChannel", {
  connected() {
    console.log("✅ Connected to PricesChannel")
    console.log("🔗 WebSocket URL:", consumer.url)
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
    console.log("📨 Received price update:", data)
    
    // Finde die Zeile in der Tabelle und aktualisiere den Preis
    const row = document.querySelector(`[data-crypto-id='${data.cryptocurrency_id}']`)
    if (row) {
      console.log("🎯 Found row for crypto ID:", data.cryptocurrency_id)
      const priceCell = row.querySelector('.price-cell')
      if (priceCell) {
        console.log("💰 Found price cell, updating...")
        const price = parseFloat(data.price)
        const formattedPrice = price >= 1 ? `$${price.toFixed(2)}` : `$${price.toFixed(6)}`
        
        // Aktualisiere den Link-Text
        const priceLink = priceCell.querySelector('a')
        if (priceLink) {
          priceLink.textContent = formattedPrice
          console.log("🔗 Updated existing price link:", formattedPrice)
        } else {
          priceCell.innerHTML = `<strong><a href="/cryptocurrencies/${data.cryptocurrency_id}/chart" target="_blank" class="text-decoration-none text-primary chart-link" title="Chart anzeigen">${formattedPrice}</a></strong>`
          console.log("🔗 Created new price link:", formattedPrice)
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
        console.log("⚠️ Price cell not found for crypto ID:", data.cryptocurrency_id)
      }
    } else {
      console.log("⚠️ Row not found for crypto ID:", data.cryptocurrency_id)
    }
  }
})

console.log("🔌 PricesChannel Setup abgeschlossen")
