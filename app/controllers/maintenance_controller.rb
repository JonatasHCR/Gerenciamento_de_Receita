class MaintenanceController < ApplicationController
  # Backup: auditado, SEM confirmação de senha.
  # Limpezas e restauração: auditadas E exigem confirmação da senha do admin.
  def index
    authorize :maintenance, :index?
    @targets       = Maintenance::DataCleanup::TARGETS
    @clients       = Client.order(:name)
    @cost_centers  = CostCenter.includes(:client).order(:cr_code)
    @backups       = Maintenance::BackupList.all
  end

  def backup
    authorize :maintenance, :backup?
    file = Maintenance::DatabaseBackup.new(user: current_user).call
    redirect_to maintenance_path,
      notice: "Backup gerado: #{File.basename(file)} (#{(File.size(file) / 1024.0).round(1)} KB)."
  rescue Maintenance::DatabaseBackup::BackupError => e
    redirect_to maintenance_path, alert: "Falha no backup: #{e.message}"
  end

  def cleanup
    authorize :maintenance, :cleanup?
    return redirect_with_wrong_password unless valid_admin_password?

    counts = Maintenance::DataCleanup.new(
      target: params[:target], user: current_user,
      client_id: params[:client_id], cost_center_id: params[:cost_center_id], month: params[:month]
    ).call
    label = Maintenance::DataCleanup.label(params[:target])
    redirect_to maintenance_path,
      notice: "Limpeza concluída — #{label}: #{counts.values.sum} registro(s) removido(s)."
  rescue Maintenance::DataCleanup::InvalidTarget
    redirect_to maintenance_path, alert: "Alvo de limpeza inválido."
  end

  def restore
    authorize :maintenance, :restore?
    return redirect_with_wrong_password unless valid_admin_password?

    path = Maintenance::DatabaseRestore.new(file: params[:file], user: current_user).call
    redirect_to maintenance_path, notice: "Banco restaurado a partir de #{File.basename(path)}."
  rescue Maintenance::DatabaseRestore::RestoreError => e
    redirect_to maintenance_path, alert: "Falha na restauração: #{e.message}"
  end

  def download
    authorize :maintenance, :download?
    path = Maintenance::BackupList.resolve(params[:file])
    return redirect_to(maintenance_path, alert: "Backup não encontrado.") unless path

    send_file path, type: "application/octet-stream", filename: File.basename(path)
  end

  private

  def valid_admin_password?
    current_user.valid_password?(params[:password].to_s)
  end

  def redirect_with_wrong_password
    redirect_to maintenance_path, alert: "Senha incorreta — nenhuma ação foi executada."
  end
end
