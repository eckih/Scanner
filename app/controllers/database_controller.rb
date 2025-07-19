class DatabaseController < ApplicationController
  def index
    @tables = ActiveRecord::Base.connection.tables
    @table_data = {}
    
    @tables.each do |table|
      begin
        # Hole die ersten 10 Datensätze jeder Tabelle
        records = ActiveRecord::Base.connection.execute("SELECT * FROM #{table} LIMIT 10")
        @table_data[table] = records
      rescue => e
        @table_data[table] = { error: e.message }
      end
    end
  end
end 