class BackfillForecastRealizedFromInvoices < ActiveRecord::Migration[8.1]
  PT_MONTHS = %w[JANEIRO FEVEREIRO MARÇO ABRIL MAIO JUNHO JULHO AGOSTO SETEMBRO OUTUBRO NOVEMBRO DEZEMBRO].freeze

  def up
    # Recalcula realized_total = soma das NFs emitidas no mês do CC.
    # Usa SQL direto para não acoplar à classe de modelo da aplicação.
    entries = select_all("SELECT id, cost_center_id, month_year FROM forecast_entries")

    entries.each do |fe|
      parts = fe["month_year"].to_s.split("/")
      idx   = PT_MONTHS.index(parts[0].to_s.upcase)
      next unless idx && parts[1].present?

      start_date = Date.new(parts[1].to_i, idx + 1, 1)
      end_date   = start_date.end_of_month

      execute(<<~SQL.squish)
        UPDATE forecast_entries
        SET realized_total = (
          SELECT COALESCE(SUM(value), 0) FROM invoices
          WHERE cost_center_id = #{fe['cost_center_id'].to_i}
            AND issued_at BETWEEN #{quote(start_date)} AND #{quote(end_date)}
        )
        WHERE id = #{fe['id'].to_i}
      SQL
    rescue ArgumentError
      next
    end
  end

  def down
    # Dado derivado — irreversível.
  end
end
