module Letters
  # Monta o hash de marcadores {{...}} da carta a partir do CC, da NF e do período.
  class LetterData
    MESES = %w[janeiro fevereiro março abril maio junho julho agosto setembro outubro
               novembro dezembro].freeze

    def initialize(cost_center:, kind:, invoice: nil, periodo_inicio: nil, periodo_fim: nil, oficio: "")
      @cc = cost_center
      @kind = kind.to_s
      @invoice = invoice
      @periodo_inicio = periodo_inicio
      @periodo_fim = periodo_fim
      @oficio = oficio
    end

    def to_h
      {
        "cliente"          => @cc.client&.name.to_s,
        "cliente_completo" => @cc.client&.full_name.presence || @cc.client&.name.to_s,
        "cr"               => @cc.cr_code.to_s,
        "contrato"         => @cc.contract_number.to_s,
        "objeto"           => @cc.object_text.to_s,
        "coordenador"      => @cc.coordinator.to_s,
        "fatura"           => @invoice&.number.to_s,
        "valor"            => brl(@invoice&.value),
        "valor_extenso"    => Letters::Extenso.real(@invoice&.value || 0),
        "data_emissao"     => data_curta(@invoice&.issued_at),
        "periodo_inicio"   => data_curta(@periodo_inicio),
        "periodo_fim"      => data_curta(@periodo_fim),
        "data"             => data_extenso(Date.current), # só a data; a cidade fica no modelo
        "tipo"             => (@kind == "reajuste" ? "medição de reajuste" : "medição principal"),
        "assunto"          => "Encaminhamento de #{@kind == 'reajuste' ? 'reajuste' : 'medição'}",
        "saudacao"         => "Prezados Senhores",
        "oficio"           => @oficio.to_s # nº do ofício: CA-{CR}-{sequência}/{ano}
      }
    end

    private

    def brl(value)
      ActiveSupport::NumberHelper.number_to_currency(
        value || 0, unit: "R$ ", separator: ",", delimiter: ".", precision: 2
      )
    end

    def data_curta(date)
      date = to_date(date)
      date ? date.strftime("%d/%m/%Y") : ""
    end

    def data_extenso(date)
      "#{format('%02d', date.day)} de #{MESES[date.month - 1]} de #{date.year}"
    end

    def to_date(value)
      return value if value.is_a?(Date)
      return nil if value.blank?
      Date.parse(value.to_s)
    rescue ArgumentError, Date::Error
      nil
    end
  end
end
