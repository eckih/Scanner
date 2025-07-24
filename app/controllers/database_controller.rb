class DatabaseController < ApplicationController
  def index
    @tables = ActiveRecord::Base.connection.tables
    @table_data = {}
    
    @tables.each do |table|
      begin
        # Für crypto_history_data zeige die neuesten 100 Einträge
        if table == 'crypto_history_data'
          result = ActiveRecord::Base.connection.execute("SELECT * FROM #{table} ORDER BY created_at DESC LIMIT 100")
        else
          # Hole die ersten 500 Zeilen jeder anderen Tabelle
          result = ActiveRecord::Base.connection.execute("SELECT * FROM #{table} LIMIT 500")
        end
        @table_data[table] = result.to_a
      rescue => e
        @table_data[table] = []
      end
    end
  end

  def table
    @table_name = params[:table]
    @columns = ActiveRecord::Base.connection.columns(@table_name)
    @data = ActiveRecord::Base.connection.execute("SELECT * FROM #{@table_name} LIMIT 100")
  end

  def execute
    @sql = params[:sql]
    begin
      @result = ActiveRecord::Base.connection.execute(@sql)
      @success = true
    rescue => e
      @error = e.message
      @success = false
    end
    
    render :index
  end
end 