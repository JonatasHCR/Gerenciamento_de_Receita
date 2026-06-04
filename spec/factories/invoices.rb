FactoryBot.define do
  factory :invoice do
    sequence(:number) { |n| n.to_s }
    client_name { Faker::Company.name }
    issued_at { Date.current }
    value { Faker::Number.decimal(l_digits: 5, r_digits: 2) }
    cost_center
  end
end
