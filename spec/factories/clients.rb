FactoryBot.define do
  factory :client do
    sequence(:name) { |n| "CLIENT_#{n}" }
    full_name { Faker::Company.name }
  end
end
