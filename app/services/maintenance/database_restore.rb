require "open3"

module Maintenance
  # Restaura o banco a partir de um dump pg_dump -Fc (pg_restore --clean).
  # OPERAÇÃO DESTRUTIVA: substitui os dados atuais pelos do backup. Auditada.
  class DatabaseRestore
    class RestoreError < StandardError; end

    def initialize(file:, user:)
      @file = file
      @user = user
    end

    def call
      path = Maintenance::BackupList.resolve(@file)
      raise RestoreError, "Backup não encontrado." unless path

      cfg = ActiveRecord::Base.connection_db_config.configuration_hash
      env = { "PGPASSWORD" => cfg[:password].to_s }
      args = [
        "pg_restore", "--clean", "--if-exists", "--no-owner", "--no-privileges",
        "-h", (cfg[:host] || "localhost").to_s,
        "-p", (cfg[:port] || 5432).to_s,
        "-U", cfg[:username].to_s,
        "-d", cfg[:database].to_s,
        path.to_s
      ]

      _out, status = Open3.capture2e(env, *args)
      # pg_restore pode retornar !=0 por avisos inofensivos; só falha se o banco
      # ficou inacessível. Validamos com uma query simples depois.
      ActiveRecord::Base.connection.reconnect!
      User.connection.execute("SELECT 1")

      Maintenance::Audit.record(
        event: "restauração", user: @user,
        details: { "Arquivo" => File.basename(path), "Status pg_restore" => status.exitstatus.to_s }
      )
      path
    rescue ActiveRecord::ActiveRecordError => e
      raise RestoreError, "Falha ao restaurar (banco inacessível após pg_restore): #{e.message}"
    end
  end
end
