class ApplicationPolicy
  attr_reader :user, :record

  def initialize(user, record)
    @user = user
    @record = record
  end

  def index?   = false
  def show?    = false
  def create?  = false
  def new?     = create?
  def update?  = false
  def edit?    = update?
  def destroy? = false

  protected

  def admin?      = user.admin?
  def financeiro? = user.financeiro?
  def gestor?     = user.gestor?
  def coordenador? = user.coordenador?

  class Scope
    def initialize(user, scope)
      @user = user
      @scope = scope
    end

    def resolve = @scope.all

    private

    attr_reader :user, :scope
  end
end
