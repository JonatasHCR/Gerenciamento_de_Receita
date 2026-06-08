module Maintenance
  # Lista os backups (.dump) da pasta backups/ e resolve um nome de arquivo com
  # segurança (sem path traversal) para download/restauração.
  module BackupList
    def self.dir = Rails.root.join("backups")

    # [{ name:, size:, mtime: }], mais recentes primeiro.
    def self.all
      Dir.glob(dir.join("*.dump")).filter_map do |p|
        next unless File.file?(p)
        st = File.stat(p)
        { name: File.basename(p), size: st.size, mtime: st.mtime }
      end.sort_by { |b| b[:mtime] }.reverse
    end

    # Resolve o caminho seguro de um backup pelo nome (basename evita traversal).
    # Retorna Pathname ou nil se não existir / não for .dump.
    def self.resolve(name)
      return nil if name.blank?
      path = dir.join(File.basename(name.to_s))
      (path.to_s.end_with?(".dump") && File.file?(path)) ? path : nil
    end
  end
end
