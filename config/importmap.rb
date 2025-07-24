# Pin npm packages by running ./bin/importmap

pin "application", preload: true
pin "@hotwired/turbo-rails", to: "turbo.min.js", preload: true
pin "@hotwired/stimulus", to: "stimulus.min.js", preload: true
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js", preload: true
pin_all_from "app/javascript/controllers", under: "controllers"

# DataTables für sortierbare Tabellen
pin "jquery", to: "https://code.jquery.com/jquery-3.6.0.min.js"
pin "datatables", to: "https://cdn.datatables.net/1.13.6/js/jquery.dataTables.min.js"
pin "datatables-bootstrap", to: "https://cdn.datatables.net/1.13.6/js/dataTables.bootstrap5.min.js" pin "@rails/actioncable", to: "actioncable.esm.js"
pin_all_from "app/javascript/channels", under: "channels"
