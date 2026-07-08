require "open3"
require "tmpdir"

module Letters
  # Converte bytes de um .docx em PDF usando o LibreOffice headless (mantém o layout
  # do modelo: timbre, logo, formatação). Sem shell (Open3 em array) → sem injeção.
  class PdfConverter
    class ConversionError < StandardError; end

    SOFFICE = ENV.fetch("SOFFICE_BIN", "soffice")

    def initialize(docx_bytes)
      @docx_bytes = docx_bytes
    end

    def call
      Dir.mktmpdir("carta") do |dir|
        docx = File.join(dir, "carta.docx")
        File.binwrite(docx, @docx_bytes)

        # Perfil isolado evita conflito quando várias conversões rodam juntas.
        _out, err, status = Open3.capture3(
          SOFFICE, "--headless", "--nologo", "--norestore",
          "-env:UserInstallation=file://#{File.join(dir, 'profile')}",
          "--convert-to", "pdf", "--outdir", dir, docx
        )
        pdf = File.join(dir, "carta.pdf")
        unless status.success? && File.exist?(pdf)
          raise ConversionError, "Falha ao converter para PDF: #{err.presence || 'soffice indisponível'}"
        end
        File.binread(pdf)
      end
    end
  end
end
