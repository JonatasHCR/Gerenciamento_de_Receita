require 'rails_helper'

RSpec.describe Receipt, type: :model do
  subject(:receipt) { build(:receipt) }

  describe "validations" do
    it { is_expected.to validate_presence_of(:payment_date) }
    it { is_expected.to validate_presence_of(:value) }
    it { is_expected.to validate_numericality_of(:value).is_greater_than(0) }
  end

  describe "associations" do
    it { is_expected.to belong_to(:invoice) }
  end

  describe "payment date not before invoice issued_at" do
    let(:invoice) { create(:invoice, issued_at: Date.new(2026, 3, 1), value: 1000) }

    it "is valid when payment_date equals issued_at" do
      receipt = build(:receipt, invoice: invoice, payment_date: Date.new(2026, 3, 1), value: 500)
      expect(receipt).to be_valid
    end

    it "is valid when payment_date is after issued_at" do
      receipt = build(:receipt, invoice: invoice, payment_date: Date.new(2026, 5, 1), value: 500)
      expect(receipt).to be_valid
    end

    it "is invalid when payment_date is before issued_at" do
      receipt = build(:receipt, invoice: invoice, payment_date: Date.new(2026, 2, 1), value: 500)
      expect(receipt).not_to be_valid
      expect(receipt.errors[:payment_date]).to include(
        match(/anterior à data de emissão/)
      )
    end
  end

  describe "value does not exceed invoice balance" do
    let(:invoice) { create(:invoice, value: 1000) }

    it "is valid when value equals remaining balance" do
      receipt = build(:receipt, invoice: invoice, value: 1000)
      expect(receipt).to be_valid
    end

    it "is invalid when value exceeds invoice balance" do
      receipt = build(:receipt, invoice: invoice, value: 1001)
      expect(receipt).not_to be_valid
      expect(receipt.errors[:value]).to be_present
    end

    it "is valid for second partial payment within balance" do
      create(:receipt, invoice: invoice, value: 600)
      receipt = build(:receipt, invoice: invoice, value: 400)
      expect(receipt).to be_valid
    end

    it "is invalid when second payment exceeds remaining balance" do
      create(:receipt, invoice: invoice, value: 600)
      receipt = build(:receipt, invoice: invoice, value: 500)
      expect(receipt).not_to be_valid
    end
  end
end
