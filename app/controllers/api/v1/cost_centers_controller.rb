module Api
  module V1
    # Centros de custo para o inventário.
    #
    # A receita é a dona deste dado: hoje o inventário mantém à mão uma cópia
    # incompleta (`tb_contratos`) do que existe aqui. Esta API é o que permite
    # aquele cadastro deixar de ser digitado.
    class CostCentersController < BaseController
      # Página grande de propósito: são poucas centenas de linhas e o consumidor
      # é um job, não uma tela. Ainda assim tem teto, para o dia em que não for.
      LIMITE_PADRAO = 500
      LIMITE_MAXIMO = 2000

      # GET /api/v1/cost_centers?updated_since=<iso8601>&limit=&offset=
      def index
        escopo = CostCenter.includes(:client).order(:updated_at, :id)

        # `policy_scope` NÃO se aplica aqui. O CostCenterPolicy::Scope filtra
        # por coordenador — regra que existe para gente. Identidade de serviço
        # não é um User e precisa enxergar tudo, senão a cópia do inventário
        # nasceria incompleta.
        marca = desde(:updated_since)
        escopo = escopo.where("cost_centers.updated_at > ?", marca) if marca

        registros = escopo.limit(limite).offset(offset)

        render json: {
          cost_centers: registros.map { |cc| serializar(cc) },
          # O consumidor guarda isto como marca d'água da próxima chamada.
          # Vem do último registro, não de `Time.current`: usar o relógio do
          # servidor perderia alterações feitas durante a própria requisição.
          watermark: registros.last&.updated_at&.iso8601(6),
          count: registros.size,
          has_more: registros.size == limite
        }
      end

      # GET /api/v1/cost_centers/deletions?since=<iso8601>
      #
      # Não há soft-delete no schema, então a trilha de exclusão é a tabela
      # `versions` do PaperTrail. Sem isto, um CC apagado aqui ficaria para
      # sempre no inventário.
      def deletions
        escopo = PaperTrail::Version
                   .where(item_type: "CostCenter", event: "destroy")
                   .order(:created_at, :id)

        marca = desde(:since)
        escopo = escopo.where("versions.created_at > ?", marca) if marca

        registros = escopo.limit(limite)

        render json: {
          deletions: registros.map { |v| serializar_exclusao(v) },
          watermark: registros.last&.created_at&.iso8601(6),
          count: registros.size,
          has_more: registros.size == limite
        }
      end

      private

      def limite
        valor = params[:limit].to_i
        return LIMITE_PADRAO if valor <= 0

        [valor, LIMITE_MAXIMO].min
      end

      def offset
        [params[:offset].to_i, 0].max
      end

      # Serialização explícita, sem `as_json` cru. Dois motivos:
      #
      #   - `coordinator_list` é método Ruby (split de `coordinator` por " / "),
      #     não coluna — `as_json` não o traria;
      #   - campos como `principal_invoiced`, `saldo` e `value_ufc` batem em
      #     `invoices` e virariam N+1 num índice de centenas de linhas.
      def serializar(cc)
        {
          cr_code: cc.cr_code,
          description: cc.description,
          contract_number: cc.contract_number,
          coordinator: cc.coordinator,
          coordinator_list: cc.coordinator_list,
          start_date: cc.start_date,
          end_date: cc.end_date,
          client: {
            name: cc.client&.name,
            full_name: cc.client&.full_name
          },
          updated_at: cc.updated_at.iso8601(6)
        }
      end

      def serializar_exclusao(versao)
        # `object` guarda o estado ANTES do destroy; é de lá que sai o cr_code,
        # já que a linha não existe mais.
        anterior = versao.reify rescue nil

        {
          cr_code: anterior&.cr_code,
          deleted_at: versao.created_at.iso8601(6)
        }
      end
    end
  end
end
