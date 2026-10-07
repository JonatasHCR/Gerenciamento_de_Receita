module Api
  module V1
    # Aditivos de valor e de prazo para o Controle Financeiro.
    class AdjustmentsController < BaseController
      # GET /api/v1/adjustments?updated_since=&limit=&offset=
      def index
        render_incremental(:adjustments, Adjustment.all) do |a|
          {
            id: a.id,
            cost_center_id: a.cost_center_id,
            kind: a.kind,
            previous_value: a.previous_value,
            new_value: a.new_value,
            previous_date: a.previous_date,
            new_date: a.new_date,
            note: a.note,
            created_at: a.created_at.iso8601(6),
            updated_at: a.updated_at.iso8601(6)
          }
        end
      end
    end
  end
end
