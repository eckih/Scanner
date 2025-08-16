class ColumnSumsController < ApplicationController
  def index
    # Lade Chart-Daten für die letzten 24 Stunden
    @chart_data = ColumnSum.chart_data(24)
    
    # Lade aktuelle Summen
    @latest_sums = ColumnSum.latest_sum
    
    # Lade Durchschnittswerte
    @average_24h = ColumnSum.average_24h(10)
    @average_1h = ColumnSum.average_1h(10)
    @average_30min = ColumnSum.average_30min(10)
  end
  
  def chart_data
    hours = params[:hours]&.to_i || 24
    hours = [1, hours, 168].sort[1] # Begrenze zwischen 1 und 168 Stunden (1 Woche)
    
    chart_data = ColumnSum.chart_data(hours)
    
    render json: {
      chart_data: chart_data,
      hours: hours,
      latest: ColumnSum.latest_sum&.as_json(only: [:sum_24h, :sum_1h, :sum_30min, :count_24h, :count_1h, :count_30min, :calculated_at])
    }
  end
  
  def calculate_now
    # Manueller Trigger für Summen-Berechnung
    ColumnSumService.calculate_and_save_sums
    
    respond_to do |format|
      format.html { redirect_to column_sums_path, notice: 'Spalten-Summen wurden neu berechnet.' }
      format.json { render json: { status: 'success', message: 'Spalten-Summen wurden neu berechnet.' } }
    end
  end
end
