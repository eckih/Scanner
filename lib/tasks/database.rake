namespace :db do
  desc "Add roc_derivative column to cryptocurrencies table"
  task add_roc_derivative: :environment do
    begin
      # Prüfe, ob die Spalte bereits existiert
      ActiveRecord::Base.connection.execute("SELECT roc_derivative FROM cryptocurrencies LIMIT 1")
      puts "roc_derivative column already exists!"
    rescue ActiveRecord::StatementInvalid => e
      if e.message.include?("no such column: roc_derivative")
        puts "Adding roc_derivative column to cryptocurrencies table..."
        ActiveRecord::Base.connection.execute("ALTER TABLE cryptocurrencies ADD COLUMN roc_derivative DECIMAL(10,2)")
        puts "Successfully added roc_derivative column!"
      else
        puts "Error: #{e.message}"
      end
    end
  end

  desc "Update schema.rb to include roc_derivative"
  task update_schema: :environment do
    puts "Updating schema.rb..."
    system("rails db:schema:dump")
    puts "Schema updated!"
  end
end 