class RemoveRealizedTotalFromForecastEntries < ActiveRecord::Migration[8.1]
  # realized_total deixa de ser armazenado — passa a ser calculado sob demanda
  # a partir do faturamento (ForecastEntry#realized_total). Sem coluna, sem sync.
  def change
    remove_column :forecast_entries, :realized_total, :decimal, precision: 15, scale: 2, default: "0.0"
  end
end
