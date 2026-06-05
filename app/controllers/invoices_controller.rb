class InvoicesController < ApplicationController
  before_action :set_invoice, only: [:show, :edit, :update, :destroy]

  def index
    authorize Invoice
    # Padrão: mostra apenas notas EM ABERTO (esconde quitadas).
    @status = params[:status].presence || "open"
    scope = policy_scope(Invoice)
              .preload(:cost_center)
              .select("invoices.*, COALESCE(r.received, 0) AS preloaded_received")
              .joins("LEFT JOIN (SELECT invoice_id, SUM(value) AS received FROM receipts GROUP BY invoice_id) r ON r.invoice_id = invoices.id")
    scope = apply_filters(scope)
    @pagy, @invoices = pagy(scope.ordered)
  end

  def show
    authorize @invoice
    @receipts = @invoice.receipts.ordered
  end

  def new
    authorize Invoice
    @invoice = Invoice.new
  end

  def create
    authorize Invoice
    @invoice = Invoice.new(invoice_params)
    if @invoice.save
      redirect_to @invoice, notice: "Nota fiscal criada com sucesso."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    authorize @invoice
  end

  def update
    authorize @invoice
    if @invoice.update(invoice_params)
      redirect_to @invoice, notice: "Nota fiscal atualizada."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @invoice
    @invoice.destroy
    redirect_to invoices_path, notice: "Nota fiscal removida."
  end

  private

  def set_invoice
    @invoice = Invoice.find(params[:id])
  end

  def invoice_params
    params.require(:invoice).permit(:number, :client_name, :issued_at, :value, :observations, :cost_center_id, :kind)
  end

  def apply_filters(scope)
    scope = scope.where("invoices.number ILIKE ?", "%#{params[:q].strip}%") if params[:q].present?
    scope = scope.where(cost_center_id: params[:cost_center_id]) if params[:cost_center_id].present?
    scope = scope.for_month(parse_month(params[:month]))  if params[:month].present?

    # Status: open (em aberto) é o padrão; paid (quitadas); all (todas).
    case @status
    when "paid"
      scope = scope.where("invoices.value <= COALESCE(r.received, 0)")
    when "all"
      # sem filtro de status
    else
      scope = scope.where("invoices.value > COALESCE(r.received, 0)")
    end
    scope
  end
end
