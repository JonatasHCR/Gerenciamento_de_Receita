require "zip"
require "nokogiri"
require "stringio"

module Letters
  # Converte modelos antigos (marcadores de letras AAA…LLL) para os marcadores
  # nomeados {{...}}, preservando todo o resto (timbre, logo, texto). Substitui
  # dentro de cada <w:t> e, se o token estiver partido entre runs, funde o parágrafo.
  class TokenConverter
    WORD_NS = "http://schemas.openxmlformats.org/wordprocessingml/2006/main".freeze
    NS = { "w" => WORD_NS }.freeze
    TEXT_PARTS = %r{\Aword/(document|header\d*|footer\d*)\.xml\z}

    # Ordem importa: tokens de 3 letras iguais, substituição direta.
    MAP = {
      "AAA" => "{{data}}",
      "BBB" => "{{oficio}}",
      "CCC" => "{{assunto}}",
      "DDD" => "{{saudacao}}",
      "EEE" => "{{fatura}}",
      "FFF" => "{{periodo_inicio}}",
      "GGG" => "{{periodo_fim}}",
      "HHH" => "{{valor}}",
      "III" => "{{tipo}}",
      "JJJ" => "{{data_emissao}}",
      "LLL" => "{{valor_extenso}}"
    }.freeze

    def initialize(docx_bytes, map: MAP)
      @docx_bytes = docx_bytes
      @map = map
      @tokens = Regexp.union(map.keys)
    end

    def call
      Zip::OutputStream.write_buffer do |out|
        Zip::File.open_buffer(StringIO.new(@docx_bytes)) do |zip|
          zip.each do |entry|
            next if entry.directory?
            content = entry.get_input_stream.read
            content = convert_xml(content) if entry.name.match?(TEXT_PARTS)
            out.put_next_entry(entry.name)
            out.write(content)
          end
        end
      end.string
    end

    private

    def convert_xml(xml)
      doc = Nokogiri::XML(xml)
      doc.xpath("//w:p", NS).each { |p| convert_paragraph(p) }
      doc.to_xml(encoding: "UTF-8", save_with: Nokogiri::XML::Node::SaveOptions::AS_XML)
    end

    def convert_paragraph(paragraph)
      texts = paragraph.xpath(".//w:t", NS)
      return if texts.empty?

      texts.each { |t| t.content = t.content.gsub(@tokens, @map) if t.content.match?(@tokens) }

      joined = texts.map(&:content).join
      return unless joined.match?(@tokens)

      merged = joined.gsub(@tokens, @map)
      texts.each_with_index do |t, i|
        t.content = (i.zero? ? merged : "")
        t["xml:space"] = "preserve"
      end
    end
  end
end
