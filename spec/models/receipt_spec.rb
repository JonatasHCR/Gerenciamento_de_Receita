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
