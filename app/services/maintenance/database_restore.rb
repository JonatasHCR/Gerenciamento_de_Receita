require "open3"

module Maintenance
  # Restaura o banco a partir de um backup da pasta backups/.
  # OPERAÇÃO DESTRUTIVA: substitui os dados atuais pelos do backup. Auditada.
  #
  # Os backups novos são .sql em texto puro (psql); os .dump antigos, em formato
  # custom, continuam restauráveis via pg_restore para não inutilizar o que já
  # está na pasta.
  class DatabaseRestore
    class RestoreError < StandardError; end

    # O pg_dump 17 escreve `SET transaction_timeout` no cabeçalho e servidores
    # mais antigos não conhecem o parâmetro. No formato custom o pg_restore
    # apenas avisa; num .sql lido com ON_ERROR_STOP a restauração morreria na
    # primeira linha, então a linha sai do fluxo antes de chegar ao psql.
    INCOMPATIVEIS = /\ASET transaction_timeout/

    def initialize(file:, user:)
      @file = file
      @user = user
    end

    def call
      path = Maintenance::BackupList.resolve(@file)
      raise RestoreError, "Backup não encontrado." unless path

      status = path.to_s.end_with?(".dump") ? restaurar_dump(path) : restaurar_sql(path)

      # O banco é a prova final: uma restauração que derrubou objetos e não os
      # recriou aparece aqui, não no código de saída.
      ActiveRecord::Base.connection.reconnect!
      User.connection.execute("SELECT 1")

      Maintenance::Audit.record(
        event: "restauração", user: @user,
        details: { "Arquivo" => File.basename(path), "Status" => status.to_s }
      )
      path
    rescue ActiveRecord::ActiveRecordError => e
      raise RestoreError, "Falha ao restaurar (banco inacessível após a restauração): #{e.message}"
    end

    private

    def conexao
      cfg = ActiveRecord::Base.connection_db_config.configuration_hash
      [
        { "PGPASSWORD" => cfg[:password].to_s },
        ["-h", (cfg[:host] || "localhost").to_s,
         "-p", (cfg[:port] || 5432).to_s,
         "-U", cfg[:username].to_s,
         "-d", cfg[:database].to_s]
      ]
    end

    def restaurar_dump(path)
      env, args = conexao
      _out, status = Open3.capture2e(
        env, "pg_restore", "--clean", "--if-exists", "--no-owner", "--no-privileges",
        *args, path.to_s
      )
      status.exitstatus
    end

    # ON_ERROR_STOP=1: sem isto o psql segue depois de um erro e sai com código
    # 0 tendo restaurado pela metade.
    def restaurar_sql(path)
      env, args = conexao
      saida, status = Open3.capture2e(
        env, "psql", "-v", "ON_ERROR_STOP=1", "-q", *args,
        stdin_data: File.foreach(path).reject { |l| l.match?(INCOMPATIVEIS) }.join
      )
      unless status.success?
        raise RestoreError, "psql falhou: #{saida.lines.last(3).join.strip}"
      end
      status.exitstatus
    end
  end
end
