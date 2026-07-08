class LetterPolicy < ApplicationPolicy
  # Gestão dos modelos e geração das cartas — dados de faturamento.
  def manage?   = admin? || financeiro?
  def generate? = admin? || financeiro?
end
