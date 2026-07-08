class Letter < ApplicationRecord
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

  # Grava a geração da carta e devolve o registro com o nº do ofício atribuído.
  # O índice único (cost_center, year, sequence) protege contra concorrência — repete
  # com a próxima sequência se houver colisão.
  def self.record!(cost_center:, kind:, invoice: nil, user: nil, year: Date.current.year)
    seq = next_sequence(cost_center, year)
    create!(cost_center: cost_center, kind: kind, invoice: invoice, user: user,
            year: year, sequence: seq, number: oficio_number(cost_center, seq, year))
  rescue ActiveRecord::RecordNotUnique
    retry
  end
end
