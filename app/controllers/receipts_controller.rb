class ReceiptsController < ApplicationController
  before_action :set_invoice_or_receipt
  before_action :set_receipt, only: [:edit, :update, :destroy]

  def new
    authorize Receipt
    @receipt = @invoice.receipts.new
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
