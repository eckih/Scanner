class BalancesController < ApplicationController
  def index
    @total_balance = Balance.latest_total_balance
    @assets_with_balance = Balance.all_assets_with_balance
    @asset_balances = @assets_with_balance.map do |asset|
      Balance.latest_by_asset(asset)
    end.compact
    
    # Get recent balance updates for the overview
    @recent_updates = Balance.recent.limit(10)
    
    # Check when the last update was
    @last_update = Balance.maximum(:updated_at)
    @update_needed = @last_update.nil? || @last_update < 5.minutes.ago
  end

  def chart_data
    asset = params[:asset] || 'TOTAL'
    hours = params[:hours]&.to_i || 24
    
    balance_data = Balance.chart_data_for_asset(asset, hours)
    
    chart_data = balance_data.map do |balance|
      {
        time: balance.created_at.strftime('%Y-%m-%d %H:%M'),
        timestamp: balance.created_at.to_i * 1000,
        usd: balance.total_usd.to_f,
        btc: balance.total_btc.to_f,
        balance: balance.total_balance.to_f
      }
    end
    
    render json: {
      data: chart_data,
      asset: asset,
      hours: hours,
      last_update: format_german_time(@last_update)
    }
  end

  def refresh_data
    begin
      BalanceService.fetch_and_update_balances
      
      redirect_to balances_path, notice: 'Balance-Daten wurden erfolgreich aktualisiert!'
    rescue => e
      Rails.logger.error "Balance-Update fehlgeschlagen: #{e.message}"
      redirect_to balances_path, alert: "Fehler beim Aktualisieren der Balance-Daten: #{e.message}"
    end
  end
end 