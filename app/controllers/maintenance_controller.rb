class MaintenanceController < ApplicationController
  # Backup: auditado, SEM reconfirmação.
  # Limpezas e restauração: auditadas E exigem autenticação RECENTE.
  #
  # Antes isto pedia a senha do admin (`current_user.valid_password?`). Com o
  # SSO não há mais senha local para conferir — e simplesmente remover a
  # checagem tiraria uma proteção real: são as duas únicas operações que apagam
  # dados de forma irreversível.
  #
  # A substituição é a reautenticação do próprio Keycloak: `prompt=login` obriga
  # a digitar a senha de novo mesmo com sessão ativa, e o `auth_time` do token
  # diz quando isso aconteceu. É mais forte que a senha local era, porque quem
  # senta numa máquina destravada não consegue passar sem saber a senha —
  # e mais forte que uma confirmação digitada, que se lê na própria tela.
  JANELA_REAUTENTICACAO = 5.minutes

  def index
    authorize :maintenance, :index?
    @targets       = Maintenance::DataCleanup::TARGETS
    @clients       = Client.order(:name)
    @cost_centers  = CostCenter.includes(:client).order(:cr_code)
    @backups       = Maintenance::BackupList.all
    @identidade_confirmada = autenticacao_recente?
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
    return exigir_reautenticacao unless autenticacao_recente?

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
    return exigir_reautenticacao unless autenticacao_recente?

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

  def autenticacao_recente?
    inicio = session[:auth_time]
    inicio.present? && Time.zone.at(inicio.to_i) > JANELA_REAUTENTICACAO.ago
  end

  # Guarda para onde voltar e manda a pessoa reautenticar. O redirect NÃO pode
  # apontar direto para o authorize: a gem omniauth-rails_csrf_protection exige
  # que o fluxo comece por POST, então a tela de manutenção mostra um botão.
  def exigir_reautenticacao
    session[:apos_reautenticacao] = maintenance_path
    redirect_to maintenance_path,
      alert: "Confirme sua identidade antes de executar esta operação."
  end
end
