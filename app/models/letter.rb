class Letter < ApplicationRecord
  class SequenceTaken < StandardError; end

  belongs_to :cost_center
  belongs_to :invoice, optional: true
  belongs_to :user, optional: true

  enum :kind, { principal: 0, reajuste: 1 }

  validates :year, :sequence, :number, presence: true

  # Nº do ofício: CA-{CR}-{sequência com 3 dígitos}/{ano}.
  def self.oficio_number(cost_center, sequence, year)
    "CA-#{cost_center.cr_code}-#{format('%03d', sequence)}/#{year}"
  end

  # Próxima sequência do CR no ano (reinicia a cada ano).
  def self.next_sequence(cost_center, year)
    where(cost_center_id: cost_center.id, year: year).maximum(:sequence).to_i + 1
  end

  def self.typed_sequence(value)
    n = value.to_s.strip.to_i
    n.positive? ? n : nil
  end

  # Como next_sequence = maior+1, gravar um nº digitado N faz o próximo auto continuar de N+1.
  def self.resolve_sequence(cost_center, year, typed)
    typed_sequence(typed) || next_sequence(cost_center, year)
  end

  # Nº digitado = usa esse nº (SequenceTaken se já existir); vazio = próxima automática
  # (repete se colidir por concorrência).
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
