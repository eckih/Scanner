import { Controller } from "@hotwired/stimulus"
import $ from "jquery"
import "datatables"
import "datatables-bootstrap"

// Connects to data-controller="datatable"
export default class extends Controller {
  connect() {
    $(this.element).DataTable({
      "language": {
        "lengthMenu": "Zeige _MENU_ Einträge pro Seite",
        "zeroRecords": "Keine Einträge gefunden",
        "info": "Zeige _START_ bis _END_ von _TOTAL_ Einträgen",
        "infoEmpty": "Keine Einträge verfügbar",
        "infoFiltered": "(gefiltert von _MAX_ Einträgen)",
        "search": "Suchen:",
        "paginate": {
          "first": "Erste",
          "last": "Letzte",
          "next": "Nächste",
          "previous": "Vorherige"
        }
      },
      "pageLength": 25,
      "order": [[ 0, "asc" ]], // Sortiere nach Rang (erste Spalte)
      "columnDefs": [
        {
          "targets": [0], // Rang Spalte
          "type": "num"
        },
        {
          "targets": [3, 5], // Preis und Market Cap Spalten
          "type": "currency"
        },
        {
          "targets": [7], // RSI Spalte
          "type": "num"
        }
      ]
    });
  }

  disconnect() {
    if ($.fn.DataTable.isDataTable(this.element)) {
      $(this.element).DataTable().destroy();
    }
  }
} 