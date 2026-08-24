class AdjustmentPolicy < ApplicationPolicy
  # Registrar segue a permissão de editar o CC; alterar/apagar o histórico
  # (que mexe no valor/prazo do contrato) fica restrito a admin e financeiro.
  def create?
    CostCenterPolicy.new(user, record.cost_center).update?
  end

  def update?  = admin? || financeiro?
  def destroy? = admin? || financeiro?
end
