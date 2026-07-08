require "zip"
require "nokogiri"
require "stringio"

module Letters
  # Preenche um modelo .docx (OOXML) substituindo marcadores {{chave}} pelos valores.
  # Trata a quebra de marcador em vários runs do Word: substitui inline quando o {{...}}
  # cabe num run e, quando está partido entre runs, funde os runs do parágrafo.
  class DocxMerge
    WORD_NS = "http://schemas.openxmlformats.org/wordprocessingml/2006/main".freeze
    NS      = { "w" => WORD_NS }.freeze
    # Arquivos com texto onde os marcadores podem aparecer.
    TEXT_PARTS = %r{\Aword/(document|header\d*|footer\d*)\.xml\z}

    def initialize(docx_bytes, data)
      @docx_bytes = docx_bytes
      @data = data.transform_keys(&:to_s)
    end

    def call
      buffer = Zip::OutputStream.write_buffer do |out|
        Zip::File.open_buffer(StringIO.new(@docx_bytes)) do |zip|
          zip.each do |entry|
            next if entry.directory?
            content = entry.get_input_stream.read
            content = replace_xml(content) if entry.name.match?(TEXT_PARTS)
            out.put_next_entry(entry.name)
            out.write(content)
          end
        end
      end
      buffer.string
    end

    private

    def replace_xml(xml)
      doc = Nokogiri::XML(xml)
      doc.xpath("//w:p", NS).each { |p| replace_paragraph(p) }
      doc.to_xml(encoding: "UTF-8", save_with: Nokogiri::XML::Node::SaveOptions::AS_XML)
    end

    def replace_paragraph(paragraph)
      texts = paragraph.xpath(".//w:t", NS)
      return if texts.empty?

      # 1) Substitui marcadores completos que cabem num único run (preserva formatação).
      texts.each { |t| t.content = substitute(t.content) if t.content.include?("{{") }

      # 2) Marcador partido entre runs? Se o texto concatenado ainda tiver {{chave}},
      #    funde tudo no primeiro <w:t> e limpa os demais.
      joined = texts.map(&:content).join
      return unless joined.include?("{{") && contains_known_token?(joined)

      merged = substitute(joined)
      texts.each_with_index do |t, i|
        t.content = (i.zero? ? merged : "")
        t["xml:space"] = "preserve"
      end
    end

    def substitute(text)
      text.gsub(/\{\{\s*([\w]+)\s*\}\}/) { |m| @data.key?($1) ? @data[$1].to_s : m }
    end

    def contains_known_token?(text)
      @data.keys.any? { |k| text.match?(/\{\{\s*#{Regexp.escape(k)}\s*\}\}/) }
    end
  end
end
