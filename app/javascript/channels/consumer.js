// Action Cable provides the framework to deal with WebSockets in Rails.
// You can generate new channels where WebSocket features live using the `bin/rails generate channel` command.

import { createConsumer } from "@rails/actioncable"

// Konfiguriere WebSocket-URL für Docker-Container
// Verwende die aktuelle Host-URL für WebSocket-Verbindung
const protocol = window.location.protocol === 'https:' ? 'wss:' : 'ws:'
const host = window.location.host
const wsUrl = `${protocol}//${host}/cable`

console.log('🔌 ActionCable WebSocket URL:', wsUrl)

const consumer = createConsumer(wsUrl)

export default consumer
