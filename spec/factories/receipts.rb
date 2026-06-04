FactoryBot.define do
  factory :receipt do
    payment_date { Date.current }
    value { invoice.value }
    invoice
  end
end
