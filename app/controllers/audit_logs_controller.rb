class AuditLogsController < ApplicationController
  def index
    authorize :audit_log, :index?
    scope = PaperTrail::Version.order(created_at: :desc)
    scope = scope.where(item_type: params[:item_type]) if params[:item_type].present?
    scope = scope.where(event: params[:event])         if params[:event].present?
    scope = scope.where(whodunnit: params[:user_id])   if params[:user_id].present?
    @pagy, @versions = pagy(scope)
    @users = User.order(:name)
    @users_by_id = @users.index_by { |u| u.id.to_s }
  end

  def show
    authorize :audit_log, :show?
    @version = PaperTrail::Version.find(params[:id])
  end
end
