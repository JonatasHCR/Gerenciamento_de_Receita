class ForecastEntryPolicy < ApplicationPolicy
  def index?  = true
  def show?   = true

  def create?
    admin? || financeiro? || gestor? || (coordenador? && own_cost_center?)
  end

  def update?
    admin? || financeiro? || gestor? || (coordenador? && own_cost_center?)
  end

  def destroy? = admin? || financeiro? || gestor?

  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.all unless user.coordenador?
      scope.joins(cost_center: :user_cost_centers)
           .where(user_cost_centers: { user_id: user.id })
    end
  end

  private

  def own_cost_center?
    return false unless record.is_a?(ForecastEntry)
    return false if record.cost_center.nil?
    record.cost_center.user_cost_centers.exists?(user_id: user.id)
  end
end
