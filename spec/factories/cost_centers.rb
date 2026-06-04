FactoryBot.define do
  factory :cost_center do
    sequence(:cr_code) { |n| (4000 + n).to_s }
    description { Faker::Lorem.words(number: 4).join(" ").upcase }
    participation { 1.0 }
    coordinator { Faker::Name.name }
    client
  end
end
