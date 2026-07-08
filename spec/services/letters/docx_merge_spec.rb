require "rails_helper"
require "zip"
require "stringio"

RSpec.describe Letters::DocxMerge do
  def docx(parts)
    Zip::OutputStream.write_buffer do |out|
      parts.each { |name, content| out.put_next_entry(name); out.write(content) }
    end.string
  end

  def doc_xml(body)
    %(<?xml version="1.0" encoding="UTF-8" standalone="yes"?><w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body>#{body}</w:body></w:document>)
  end

  def read(bytes, entry)
    out = nil
    Zip::File.open_buffer(StringIO.new(bytes)) { |z| out = z.get_entry(entry).get_input_stream.read }
    out
  end

  def text(bytes, entry = "word/document.xml")
    read(bytes, entry).gsub(/<[^>]*>/, "")
  end

  it "substitui marcador contido num único run" do
    bytes = docx("word/document.xml" => doc_xml("<w:p><w:r><w:t>Fatura {{fatura}}</w:t></w:r></w:p>"))
    out = described_class.new(bytes, { "fatura" => "NF-1" }).call
    expect(text(out)).to include("Fatura NF-1")
    expect(text(out)).not_to include("{{")
  end

  it "substitui marcador quebrado entre vários runs" do
    body = "<w:p><w:r><w:t>{{fat</w:t></w:r><w:r><w:t>ura}}</w:t></w:r></w:p>"
    out = described_class.new(docx("word/document.xml" => doc_xml(body)), { "fatura" => "NF-9" }).call
    expect(text(out)).to include("NF-9")
    expect(text(out)).not_to include("{{")
  end

  it "substitui também em header e footer" do
    bytes = docx(
      "word/document.xml" => doc_xml("<w:p><w:r><w:t>corpo</w:t></w:r></w:p>"),
      "word/header1.xml"  => doc_xml("<w:p><w:r><w:t>{{cliente}}</w:t></w:r></w:p>"),
      "word/footer2.xml"  => doc_xml("<w:p><w:r><w:t>{{cr}}</w:t></w:r></w:p>")
    )
    out = described_class.new(bytes, { "cliente" => "CONDER", "cr" => "4501" }).call
    expect(text(out, "word/header1.xml")).to include("CONDER")
    expect(text(out, "word/footer2.xml")).to include("4501")
  end

  it "escapa XML no valor substituído (& < >)" do
    bytes = docx("word/document.xml" => doc_xml("<w:p><w:r><w:t>Valor {{x}}</w:t></w:r></w:p>"))
    out = described_class.new(bytes, { "x" => "A & B < C" }).call
    raw = read(out, "word/document.xml")
    expect(raw).to include("A &amp; B &lt; C") # valor escapado com segurança
    expect(raw).to include("Valor ")           # texto sem marcador preservado
  end

  it "mantém marcador desconhecido intacto" do
    bytes = docx("word/document.xml" => doc_xml("<w:p><w:r><w:t>{{desconhecido}}</w:t></w:r></w:p>"))
    out = described_class.new(bytes, { "fatura" => "X" }).call
    expect(text(out)).to include("{{desconhecido}}")
  end
end
