FactoryBot.define do
  factory :user do
    name { Faker::Name.name }
    sequence(:email) { |n| "user#{n}@example.com" }
    password { "password123" }
    password_confirmation { "password123" }
    role { :coordenador }

    trait :admin do
      role { :admin }
    end

    trait :financeiro do
      role { :financeiro }
    end

    trait :gestor do
      role { :gestor }
    end

    trait :coordenador do
      role { :coordenador }
    end
  end
end
