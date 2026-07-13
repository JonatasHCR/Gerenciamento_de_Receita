# Só o último nº de ofício gerado por CR/ano — as cartas em si não são armazenadas.
# Serve apenas para o "auto" continuar a contagem; repetir um nº nunca impede a geração.
class LetterSequence < ApplicationRecord
  belongs_to :cost_center

  validates :year, :last_sequence, presence: true

  # Nº do ofício: CA-{CR}-{sequência com 3 dígitos}/{ano}.
  def self.oficio_number(cost_center, sequence, year)
    "CA-#{cost_center.cr_code}-#{format('%03d', sequence)}/#{year}"
  end

  # Próxima sequência do CR no ano (reinicia a cada ano).
  def self.next_sequence(cost_center, year)
    where(cost_center_id: cost_center.id, year: year).pick(:last_sequence).to_i + 1
  end

  def self.typed_sequence(value)
    n = value.to_s.strip.to_i
    n.positive? ? n : nil
  end

  def self.resolve_sequence(cost_center, year, typed)
    typed_sequence(typed) || next_sequence(cost_center, year)
  end

  # Registra o nº gerado guardando só o maior já usado — um nº menor (reemissão de uma
  # carta antiga) não faz a contagem retroceder.
  def self.bump!(cost_center, year, sequence)
    row = find_or_initialize_by(cost_center_id: cost_center.id, year: year)
    row.last_sequence = [row.last_sequence.to_i, sequence].max
    row.save!
    sequence
  rescue ActiveRecord::RecordNotUnique
    retry
  end
end
