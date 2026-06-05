class RemovePctUfcFromForecastEntries < ActiveRecord::Migration[8.1]
  # % UFC previsto/realizado não são mais usados. realized_total permanece
  # (é derivado do faturamento e exibido no dashboard/relatório/previsão).
  def change
    remove_column :forecast_entries, :forecasted_pct_ufc, :decimal, precision: 15, scale: 2, default: "0.0"
    remove_column :forecast_entries, :realized_pct_ufc,   :decimal, precision: 15, scale: 2, default: "0.0"
  end
end
