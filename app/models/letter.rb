class Letter < ApplicationRecord
  # Nº digitado que já existe para o CR/ano (índice único violado).
  class SequenceTaken < StandardError; end

  belongs_to :cost_center
  belongs_to :invoice, optional: true
  belongs_to :user, optional: true

  enum :kind, { principal: 0, reajuste: 1 }

  validates :year, :sequence, :number, presence: true

  # Número do ofício no formato CA-{CR}-{sequência}/{ano}; sequência com 3 dígitos (001, 010).
  def self.oficio_number(cost_center, sequence, year)
    "CA-#{cost_center.cr_code}-#{format('%03d', sequence)}/#{year}"
  end

  # Próxima sequência de um CR num ano (sequência reinicia a cada ano). Usado no preview
  # para exibir o número previsto sem gravar.
  def self.next_sequence(cost_center, year)
    where(cost_center_id: cost_center.id, year: year).maximum(:sequence).to_i + 1
  end

  # Converte um nº digitado em inteiro válido (> 0) ou nil. String vazia/lixo → nil (auto).
  def self.typed_sequence(value)
    n = value.to_s.strip.to_i
    n.positive? ? n : nil
  end

  # Sequência a exibir/usar: a digitada (se válida) ou a próxima automática. Como
  # next_sequence = maior+1, gravar um nº digitado N faz o próximo auto continuar de N+1.
  def self.resolve_sequence(cost_center, year, typed)
    typed_sequence(typed) || next_sequence(cost_center, year)
  end

  # Grava a geração da carta e devolve o registro com o nº do ofício atribuído.
  # `sequence` digitada = usa esse nº (erro se já existir); vazia = próxima automática
  # (o índice único protege contra concorrência — repete o auto se colidir).
  def self.record!(cost_center:, kind:, invoice: nil, user: nil, year: Date.current.year, sequence: nil)
    typed = typed_sequence(sequence)
    seq = typed || next_sequence(cost_center, year)
    create!(cost_center: cost_center, kind: kind, invoice: invoice, user: user,
            year: year, sequence: seq, number: oficio_number(cost_center, seq, year))
  rescue ActiveRecord::RecordNotUnique
    raise SequenceTaken, "O ofício nº #{format('%03d', seq)} já existe para este CR em #{year}." if typed
    retry
  end
end
