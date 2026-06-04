class AddIndexToForecastEntriesMonthYear < ActiveRecord::Migration[8.1]
  def change
    add_index :forecast_entries, :month_year
  end
end
