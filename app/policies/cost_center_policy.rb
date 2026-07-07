class CostCenterPolicy < ApplicationPolicy
  def index?  = true

  # Coordenador só enxerga os CCs próprios (mesmo acessando /cost_centers/:id
  # direto ou via página de um cliente). Gestor/financeiro/admin veem todos.
  def show?
    admin? || financeiro? || gestor? || (coordenador? && own_cost_center?)
  end

  # Coordenador pode criar CC — o controller fixa o coordenador no próprio nome,
  # então o CC nasce vinculado a ele.
  def create?
    admin? || financeiro? || gestor? || coordenador?
  end

  def update?
    admin? || financeiro? || gestor? || (coordenador? && own_cost_center?)
  end

  def destroy? = admin?

  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.all unless user.coordenador?
      scope.joins(:user_cost_centers).where(user_cost_centers: { user_id: user.id })
    end
  end

  private

  def own_cost_center?
    return false unless record.is_a?(CostCenter)
    record.users.include?(user)
  end
end
