require 'rails_helper'

RSpec.describe Invoice, type: :model do
  subject(:invoice) { build(:invoice) }

  describe "validations" do
    it { is_expected.to validate_presence_of(:number) }
    it { is_expected.to validate_presence_of(:client_name) }
    it { is_expected.to validate_presence_of(:issued_at) }
    it { is_expected.to validate_presence_of(:value) }
    it { is_expected.to validate_numericality_of(:value).is_greater_than(0) }
  end

  describe "associations" do
    it { is_expected.to belong_to(:cost_center) }
    it { is_expected.to have_many(:receipts).dependent(:destroy) }
  end

  describe "#balance" do
    let(:invoice) { create(:invoice, value: 3000) }

    it "returns full value when no receipts" do
      expect(invoice.balance).to eq(3000)
    end

    it "returns remaining value after partial receipt" do
      create(:receipt, invoice: invoice, value: 1500)
      expect(invoice.balance).to eq(1500)
    end

    it "returns zero after full payment" do
      create(:receipt, invoice: invoice, value: 3000)
      expect(invoice.balance).to eq(0)
    end
  end

  describe "#payment_status" do
    let(:invoice) { create(:invoice, value: 3000) }

    it "returns :unpaid when no receipts" do
      expect(invoice.payment_status).to eq(:unpaid)
    end

    it "returns :partial when partially paid" do
      create(:receipt, invoice: invoice, value: 1500)
      expect(invoice.payment_status).to eq(:partial)
    end

    it "returns :paid when fully paid" do
      create(:receipt, invoice: invoice, value: 3000)
      expect(invoice.payment_status).to eq(:paid)
    end
  end
end
