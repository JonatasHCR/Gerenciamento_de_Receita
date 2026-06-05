FactoryBot.define do
  factory :forecast_entry do
    month_year { "JUNHO/2026" }
    forecasted_total { 100_000.0 }
    cost_center
  end
end
