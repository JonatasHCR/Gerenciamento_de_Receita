module Maintenance
  # Limpezas de dados de negócio (auditadas), com filtros opcionais:
  #   - cliente (client_id), centro de custo (cost_center_id), mês/ano ("AAAA-MM")
  #   - sem filtro = geral (todo o alvo).
  # Apaga em ordem de dependência (FKs sem ON DELETE CASCADE) numa transação.
  # NUNCA apaga usuários nem a auditoria (versions).
  class DataCleanup
    class InvalidTarget < StandardError; end

    TARGETS = {
      "previsao"     => "Previsões",
      "recebimentos" => "Recebimentos",
      "faturamento"  => "Faturamento (NFs e recebimentos)",
      "centros"      => "Centros de Custo (e tudo vinculado)",
      "tudo"         => "Tudo (dados de negócio — NÃO inclui auditoria)",
      "auditoria"    => "Auditoria (histórico de alterações)"
    }.freeze

    def self.label(target) = TARGETS[target.to_s]

    def initialize(target:, user:, client_id: nil, cost_center_id: nil, month: nil)
      @target         = target.to_s
      @user           = user
      @client_id      = client_id.presence
      @cost_center_id = cost_center_id.presence
      @month          = month.presence
    end

    # Retorna { modelo => quantidade_removida }.
    def call
      raise InvalidTarget unless TARGETS.key?(@target)

      counts = {}
      ActiveRecord::Base.transaction { counts = perform }

      Maintenance::Audit.record(
        event: "limpeza", user: @user,
        details: { "Alvo" => TARGETS[@target], "Filtros" => filtros_descricao }
                   .merge(counts.transform_keys { |k| "Removidos (#{k})" })
      )
      counts
    end

    private

    def perform
      case @target
      when "previsao"     then clean_forecasts
      when "recebimentos" then clean_receipts
      when "faturamento"  then clean_invoices
      when "centros"      then clean_cost_centers
      when "tudo"         then wipe_all # ignora filtros
      when "auditoria"    then { versions: PaperTrail::Version.delete_all } # histórico de auditoria
      end
    end

    def clean_forecasts
      s = ForecastEntry.all
      s = s.where(cost_center_id: cost_center_ids) if cost_center_ids
      s = s.where(month_year: forecast_month_year) if forecast_month_year
      { forecast_entries: s.delete_all }
    end

    def clean_receipts
      s = Receipt.all
      s = s.where(invoice_id: Invoice.where(cost_center_id: cost_center_ids).select(:id)) if cost_center_ids
      s = s.where(payment_date: month_range) if month_range
      { receipts: s.delete_all }
    end

    def clean_invoices
      s = Invoice.all
      s = s.where(cost_center_id: cost_center_ids) if cost_center_ids
      s = s.where(issued_at: month_range) if month_range
      ids = s.ids
      { receipts: Receipt.where(invoice_id: ids).delete_all, invoices: Invoice.where(id: ids).delete_all }
    end

    # Remove CCs (filtrados por cliente/CC) e tudo que depende deles.
    def clean_cost_centers
      ids = cost_center_ids || CostCenter.ids
      inv = Invoice.where(cost_center_id: ids).ids
      {
        receipts:          Receipt.where(invoice_id: inv).delete_all,
        invoices:          Invoice.where(id: inv).delete_all,
        forecast_entries:  ForecastEntry.where(cost_center_id: ids).delete_all,
        adjustments:       Adjustment.where(cost_center_id: ids).delete_all,
        user_cost_centers: UserCostCenter.where(cost_center_id: ids).delete_all,
        letter_templates:  LetterTemplate.where(cost_center_id: ids).delete_all,
        letter_sequences:  LetterSequence.where(cost_center_id: ids).delete_all,
        cost_centers:      CostCenter.where(id: ids).delete_all
      }
    end

    def wipe_all
      {
        receipts:          Receipt.delete_all,
        invoices:          Invoice.delete_all,
        forecast_entries:  ForecastEntry.delete_all,
        adjustments:       Adjustment.delete_all,
        user_cost_centers: UserCostCenter.delete_all,
        letter_templates:  LetterTemplate.delete_all,
        letter_sequences:  LetterSequence.delete_all,
        cost_centers:      CostCenter.delete_all,
        clients:           Client.delete_all
      }
    end

    # ── Filtros ────────────────────────────────────────────────────────────────
    def cost_center_ids
      return @cc_ids if defined?(@cc_ids)
      @cc_ids =
        if @cost_center_id then [@cost_center_id.to_i]
        elsif @client_id   then CostCenter.where(client_id: @client_id).ids
        end
    end

    def month_range
      return @range if defined?(@range)
      @range =
        if @month && (m = @month.match(/\A(\d{4})-(\d{1,2})\z/)) && (1..12).cover?(m[2].to_i)
          d = Date.new(m[1].to_i, m[2].to_i, 1)
          d.beginning_of_month..d.end_of_month
        end
    end

    def forecast_month_year
      month_range && ForecastEntry.month_year_for(month_range.begin)
    end

    def filtros_descricao
      return "geral (tudo)" if @target == "tudo"

      parts = []
      parts << "Cliente=#{Client.find_by(id: @client_id)&.name}"          if @client_id
      parts << "CC=#{CostCenter.find_by(id: @cost_center_id)&.cr_code}"   if @cost_center_id
      parts << "Mês=#{@month}"                                            if @month && @target != "centros"
      parts.any? ? parts.join(", ") : "geral (sem filtro)"
    end
  end
end
