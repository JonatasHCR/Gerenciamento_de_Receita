require "zip"
require "stringio"

module Letters
  # Gera um modelo-base .docx (mínimo, válido) com os marcadores {{...}} e um texto de
  # exemplo, para o usuário baixar, adaptar no Word e reenviar como o modelo do CR.
  class BaseTemplateGenerator
    def initialize(kind = "principal")
      @kind = kind.to_s == "reajuste" ? "reajuste" : "principal"
    end

    def call
      buffer = Zip::OutputStream.write_buffer do |out|
        { "[Content_Types].xml" => content_types,
          "_rels/.rels" => rels,
          "word/document.xml" => document }.each do |name, xml|
          out.put_next_entry(name)
          out.write(xml)
        end
      end
      buffer.string
    end

    private

    def paragraphs
      [
        "Lauro de Freitas, {{data}}. {{oficio}}",
        "",
        "Ao(À) {{cliente_completo}}",
        "REF.: CONTRATO Nº {{contrato}} — {{objeto}}",
        "ASSUNTO: {{assunto}}",
        "",
        "{{saudacao}},",
        "",
        "Encaminhamos a fatura nº {{fatura}} referente ao período de {{periodo_inicio}} " \
        "a {{periodo_fim}}, no valor de {{valor}} ({{valor_extenso}}), relativa à {{tipo}} " \
        "do contrato em referência (CR {{cr}}).",
        "",
        "Atenciosamente,",
        "",
        "{{coordenador}}"
      ]
    end

    def document
      body = paragraphs.map { |t| para(t) }.join
      <<~XML
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
          <w:body>#{body}<w:sectPr/></w:body>
        </w:document>
      XML
    end

    def para(text)
      if text.empty?
        "<w:p/>"
      else
        "<w:p><w:r><w:t xml:space=\"preserve\">#{escape(text)}</w:t></w:r></w:p>"
      end
    end

    def escape(text)
      text.gsub("&", "&amp;").gsub("<", "&lt;").gsub(">", "&gt;")
    end

    def content_types
      <<~XML
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
          <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
          <Default Extension="xml" ContentType="application/xml"/>
          <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
        </Types>
      XML
    end

    def rels
      <<~XML
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
          <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
        </Relationships>
      XML
    end
  end
end
