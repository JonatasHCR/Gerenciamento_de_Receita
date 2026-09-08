FactoryBot.define do
  factory :user do
    name { Faker::Name.name }
    sequence(:email) { |n| "user#{n}@example.com" }
    # Sem password/password_confirmation: o :database_authenticatable saiu do
    # modelo. `sign_in` dos helpers do Devise usa Warden direto, entao os specs
    # de request continuam funcionando sem senha.
    sequence(:external_id) { |n| "sub-teste-#{n}" }
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
