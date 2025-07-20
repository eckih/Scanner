class DatabaseController < ApplicationController
  def index
    @tables = ActiveRecord::Base.connection.tables
    @table_data = {}
    
    @tables.each do |table|
      begin
        # Hole die ersten 500 Zeilen jeder Tabelle
        result = ActiveRecord::Base.connection.execute("SELECT * FROM #{table} LIMIT 500")
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