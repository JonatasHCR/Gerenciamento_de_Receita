class ReceiptsController < ApplicationController
  before_action :set_invoice_or_receipt, except: [:index]
  before_action :set_receipt, only: [:edit, :update, :destroy]

  def index
    authorize Receipt
    scope = policy_scope(Receipt).includes(invoice: :cost_center)
    scope = scope.for_month(parse_month(params[:month])) if params[:month].present?
    scope = scope.where(invoices: { cost_center_id: params[:cost_center_id] }) if params[:cost_center_id].present?
    @pagy, @receipts = pagy(scope.order(payment_date: :desc))
  end

  def new
    authorize Receipt
    if @invoice
      @receipt = @invoice.receipts.new
    else
      # Fluxo a partir da página de Recebimentos: busca a NF pelo número.
      @receipt = Receipt.new
      if params[:q].present?
        @invoices = policy_scope(Invoice)
                      .where("invoices.number ILIKE ?", "%#{params[:q].strip}%")
                      .includes(:cost_center)
                      .order(issued_at: :desc)
                      .limit(20)
      end
    end
  end

  def create
    authorize Receipt
    @receipt = @invoice.receipts.new(receipt_params)
    if @receipt.save
      redirect_to @invoice, notice: "Recebimento registrado com sucesso."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    authorize @receipt
  end

  def update
    authorize @receipt
    if @receipt.update(receipt_params)
      redirect_to @invoice, notice: "Recebimento atualizado."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @receipt
    @receipt.destroy
    @invoice.reload
    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to @invoice, notice: "Recebimento removido." }
    end
  end

  private

  def set_invoice_or_receipt
    if params[:invoice_id]
      @invoice = Invoice.find(params[:invoice_id])
    end
  end

  def set_receipt
    @receipt = Receipt.find(params[:id])
    @invoice ||= @receipt.invoice
  end

  def receipt_params
    params.require(:receipt).permit(:payment_date, :value, :observations)
  end
end
