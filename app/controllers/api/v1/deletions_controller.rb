module Api
  module V1
    # Exclusões de qualquer tabela espelhada pelo Controle Financeiro, lidas do PaperTrail.
    class DeletionsController < BaseController
      TIPOS = %w[Client CostCenter Invoice Receipt Adjustment ForecastEntry].freeze

      # GET /api/v1/deletions?since=<iso8601>&types=Invoice,Receipt&limit=
      def index
        tipos = params[:types].to_s.split(",").map(&:strip) & TIPOS
        tipos = TIPOS if tipos.empty?

        escopo = PaperTrail::Version.where(item_type: tipos, event: "destroy").order(:created_at, :id)
        escopo = depois_de(escopo, "versions.created_at", "versions.id", :since)

        registros = escopo.limit(limite_pagina).offset(offset_pagina).to_a
        render json: {
          deletions: registros.map { |v| { item_type: v.item_type, item_id: v.item_id, deleted_at: v.created_at.iso8601(6) } },
          watermark: registros.last&.created_at&.iso8601(6),
          last_id: registros.last&.id,
          count: registros.size,
          has_more: registros.size == limite_pagina
        }
      end
    end
  end
end
