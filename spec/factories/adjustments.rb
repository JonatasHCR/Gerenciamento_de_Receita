FactoryBot.define do
  factory :adjustment do
    cost_center
    kind { :valor }
    new_value { 60_000.0 }

    trait :prazo do
      kind { :prazo }
      new_value { nil }
      new_date { Date.current.next_year }
    end
  end
end
