require 'rails_helper'

RSpec.describe Invoices::OpenInvoicesQuery do
  describe "#call" do
    let!(:unpaid_invoice)   { create(:invoice, value: 1000) }
    let!(:partial_invoice)  { create(:invoice, value: 1000).tap { |i| create(:receipt, invoice: i, value: 400) } }
    let!(:paid_invoice)     { create(:invoice, value: 500).tap  { |i| create(:receipt, invoice: i, value: 500) } }

    it "returns unpaid invoices" do
      result = described_class.new.call
      expect(result).to include(unpaid_invoice)
    end

    it "returns partially paid invoices" do
      result = described_class.new.call
      expect(result).to include(partial_invoice)
    end

    it "excludes fully paid invoices" do
      result = described_class.new.call
      expect(result).not_to include(paid_invoice)
    end
  end
end
