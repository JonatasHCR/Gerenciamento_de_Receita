module Invoices
  class OpenInvoicesQuery
    def initialize(relation = Invoice.all)
      @relation = relation
    end

    def call
      @relation.with_open_balance.includes(:cost_center, :receipts).ordered
    end
  end
end
