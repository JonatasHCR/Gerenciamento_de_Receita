require "fileutils"

module Maintenance
  # Gera um dump pg_dump -Fc no MESMO diretório (./backups) usado pelo sidecar e
  # pelo scripts/restore.sh. Roda dentro do container web (que tem pg_dump e
  # alcança o serviço "db"). É a mesma operação do scripts/backup.sh, só disparada
  # pela aplicação em vez do host.
  class DatabaseBackup
    class BackupError < StandardError; end

    def initialize(user:)
      @user = user
    end

    # Retorna o Pathname do arquivo gerado.
    def call
      dir = Rails.root.join("backups")
      FileUtils.mkdir_p(dir)
      file = dir.join("manual_#{Time.current.strftime('%Y%m%d_%H%M%S')}.dump")

      cfg = ActiveRecord::Base.connection_db_config.configuration_hash
      env = { "PGPASSWORD" => cfg[:password].to_s }
      args = [
        "pg_dump", "-Fc",
        "-h", (cfg[:host] || "localhost").to_s,
        "-p", (cfg[:port] || 5432).to_s,
        "-U", cfg[:username].to_s,
        "-d", cfg[:database].to_s,
        "-f", file.to_s
      ]

      ok = system(env, *args)
      unless ok && File.exist?(file) && File.size(file).positive?
        FileUtils.rm_f(file)
        raise BackupError, "pg_dump não gerou o arquivo (verifique pg_dump e a conexão com o banco)."
      end

      Maintenance::Audit.record(
        event: "backup", user: @user,
        details: { "Arquivo" => File.basename(file), "Tamanho" => "#{(File.size(file) / 1024.0).round(1)} KB" }
      )
      file
    end
  end
end
