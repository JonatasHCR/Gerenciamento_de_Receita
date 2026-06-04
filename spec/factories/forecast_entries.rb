FactoryBot.define do
  factory :forecast_entry do
    month_year { "JUNHO/2026" }
    forecasted_total { 100_000.0 }
    forecasted_pct_ufc { 100_000.0 }
    realized_total { 0.0 }
    realized_pct_ufc { 0.0 }
    cost_center
  end
end
