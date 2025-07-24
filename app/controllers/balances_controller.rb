class BalancesController < ApplicationController
  def index
    @balances = Balance.all
    @assets_with_balance = @balances.select { |b| b.total_usd > 0 }
    @asset_balances = @assets_with_balance
    @total_usd_value = @balances.sum(&:total_usd)
    @total_btc_value = @balances.sum(&:total_btc)
    @last_update = @balances.maximum(:created_at)
  end

  def chart_data
    @balances = Balance.all
    @chart_data = @balances.map do |balance|
      {
        x: balance.created_at.to_i * 1000,
        y: balance.total_usd
      }
    end
    
    render json: @chart_data
  end
end 