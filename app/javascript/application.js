// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
console.log("🚀 Application.js lädt...")

import "@hotwired/turbo-rails"
console.log("✅ Turbo Rails geladen")

import "controllers"
console.log("✅ Controllers geladen")

import "channels"
console.log("✅ Channels geladen")

// ActionCable wird jetzt direkt über CDN geladen

console.log("🚀 Application.js Setup abgeschlossen")

