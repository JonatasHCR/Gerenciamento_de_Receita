module Keycloak
  # Renova o token e relê os grupos, para a remoção no Keycloak valer sem
  # esperar o próximo login.
  class Revalidacao
    MARGEM = 60

    Resultado = Struct.new(:ok, :grupos, :refresh_token, :expira_em, :erro, keyword_init: true)

    def self.renovar(refresh_token)
      new.renovar(refresh_token)
    end

    def renovar(refresh_token)
      return Resultado.new(ok: false, erro: "sem refresh token") if refresh_token.blank?

      token = trocar_refresh(refresh_token)
      return Resultado.new(ok: false, erro: "refresh recusado") if token.nil?

      claims = userinfo(token["access_token"])
      return Resultado.new(ok: false, erro: "userinfo indisponível") if claims.nil?

      Resultado.new(
        ok: true,
        grupos: Array(claims["groups"]),
        refresh_token: token["refresh_token"].presence || refresh_token,
        expira_em: Time.current.to_i + token.fetch("expires_in", 300).to_i
      )
    end

    private

    def base
      host = ENV.fetch("HOST_IP")
      porta = ENV.fetch("KEYCLOAK_PORT", "8080")
      "http://#{host}:#{porta}/realms/ufc/protocol/openid-connect"
    end

    def trocar_refresh(refresh_token)
      resposta = post(
        "#{base}/token",
        grant_type: "refresh_token",
        refresh_token: refresh_token,
        client_id: ENV.fetch("OIDC_CLIENT_ID", "receita-web"),
        client_secret: ENV.fetch("OIDC_CLIENT_SECRET")
      )
      resposta.is_a?(Net::HTTPSuccess) ? JSON.parse(resposta.body) : nil
    rescue StandardError => e
      Rails.logger.info("[revalidacao] refresh falhou: #{e.class}: #{e.message}")
      nil
    end

    def userinfo(access_token)
      uri = URI("#{base}/userinfo")
      requisicao = Net::HTTP::Get.new(uri)
      requisicao["Authorization"] = "Bearer #{access_token}"
      resposta = executar(uri, requisicao)
      resposta.is_a?(Net::HTTPSuccess) ? JSON.parse(resposta.body) : nil
    rescue StandardError => e
      Rails.logger.info("[revalidacao] userinfo falhou: #{e.class}: #{e.message}")
      nil
    end

    def post(url, **campos)
      uri = URI(url)
      requisicao = Net::HTTP::Post.new(uri)
      requisicao.set_form_data(campos)
      executar(uri, requisicao)
    end

    def executar(uri, requisicao)
      Net::HTTP.start(
        uri.hostname, uri.port,
        use_ssl: uri.scheme == "https",
        open_timeout: 5, read_timeout: 5
      ) { |http| http.request(requisicao) }
    end
  end
end
