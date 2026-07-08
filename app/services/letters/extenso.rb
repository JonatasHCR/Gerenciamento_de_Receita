require "bigdecimal"
require "bigdecimal/util"

module Letters
  # Valor monetário por extenso em português (reais/centavos). Aproximação boa para
  # cartas; o usuário confere no preview antes de enviar.
  module Extenso
    UNIDADES = %w[zero um dois três quatro cinco seis sete oito nove dez onze doze treze
                  quatorze quinze dezesseis dezessete dezoito dezenove].freeze
    DEZENAS  = [nil, nil, "vinte", "trinta", "quarenta", "cinquenta", "sessenta",
                "setenta", "oitenta", "noventa"].freeze
    CENTENAS = [nil, "cento", "duzentos", "trezentos", "quatrocentos", "quinhentos",
                "seiscentos", "setecentos", "oitocentos", "novecentos"].freeze
    ESCALAS  = [["", ""], ["mil", "mil"], ["milhão", "milhões"], ["bilhão", "bilhões"]].freeze

    module_function

    def real(value)
      v = value.to_d
      reais = v.to_i
      centavos = ((v - reais).abs * 100).round.to_i
      partes = []
      partes << "#{numero(reais)} #{reais == 1 ? 'real' : 'reais'}" if reais.positive?
      partes << "#{numero(centavos)} #{centavos == 1 ? 'centavo' : 'centavos'}" if centavos.positive?
      partes << "zero reais" if partes.empty?
      partes.join(" e ")
    end

    def numero(n)
      return UNIDADES[0] if n.zero?

      grupos = []
      while n.positive?
        grupos << (n % 1000)
        n /= 1000
      end

      partes = []
      grupos.each_with_index do |g, idx|
        next if g.zero?
        sing, plur = ESCALAS[idx] || ["", ""]
        texto =
          if idx == 1 && g == 1
            "mil"
          elsif idx >= 1
            escala = (g == 1 ? sing : plur)
            escala.empty? ? grupo(g) : "#{grupo(g)} #{escala}"
          else
            grupo(g)
          end
        partes.unshift(texto)
      end
      partes.join(" ")
    end

    def grupo(n)
      return "cem" if n == 100
      c = n / 100
      resto = n % 100
      out = []
      out << CENTENAS[c] if c.positive?
      if resto.positive?
        if resto < 20
          out << UNIDADES[resto]
        else
          d = resto / 10
          u = resto % 10
          dez = DEZENAS[d]
          dez = "#{dez} e #{UNIDADES[u]}" if u.positive?
          out << dez
        end
      end
      out.join(" e ")
    end
  end
end
