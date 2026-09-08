module Api
  module V1
    # Base das rotas de máquina.
    #
    # Herda de `ActionController::API`, e NÃO de ApplicationController, por dois
    # motivos concretos:
    #
    #   1. `allow_browser versions: :modern` devolve 406 para qualquer cliente
    #      que não seja um navegador moderno — o que inclui todo cliente HTTP;
    #   2. o `before_action :authenticate_user!` global exige uma sessão Devise,
    #      e aqui quem chama não é uma pessoa.
    #
    # Autenticação é por token estático em `Authorization: Bearer`, comparado
    # com `secure_compare` (tempo constante). Não é OIDC de propósito: o
    # consumidor é o job de sincronização do inventário, não um usuário — e um
    # client_credentials no Keycloak só acrescentaria uma peça para o mesmo
    # resultado.
    class BaseController < ActionController::API
      before_action :autenticar_servico!

      private

      def autenticar_servico!
        esperado = ENV["SYNC_API_TOKEN"].to_s
        if esperado.blank?
          return render json: { error: "SYNC_API_TOKEN não configurado no servidor." },
                        status: :service_unavailable
        end

        recebido = request.authorization.to_s.sub(/\ABearer\s+/i, "")

        # `secure_compare` levanta se os tamanhos diferem; o digest iguala o
        # comprimento e mantém a comparação em tempo constante.
        ok = ActiveSupport::SecurityUtils.secure_compare(
          ::Digest::SHA256.hexdigest(recebido),
          ::Digest::SHA256.hexdigest(esperado)
        )
        return if ok

        render json: { error: "Não autorizado." }, status: :unauthorized
      end

      # Marca d'água da sincronização. Sem parâmetro, devolve tudo — é o que a
      # primeira carga faz.
      def desde(param)
        valor = params[param]
        return nil if valor.blank?

        Time.zone.parse(valor.to_s)
      rescue ArgumentError
        nil
      end
    end
  end
end
