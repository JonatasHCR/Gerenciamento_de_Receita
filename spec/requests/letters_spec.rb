require "rails_helper"
require "zip"
require "stringio"

RSpec.describe "Letters", type: :request do
  def document_xml(bytes)
    out = nil
    Zip::File.open_buffer(StringIO.new(bytes)) { |z| out = z.get_entry("word/document.xml").get_input_stream.read }
    out
  end

  let(:admin)      { create(:user, :admin) }
  let(:financeiro) { create(:user, :financeiro) }
  let(:client)     { create(:client, name: "CONDER Teste") }
  let(:cc)         { create(:cost_center, client: client, cr_code: "LT-1", contract_number: "024/2022") }
  let(:docx_bytes) { Letters::BaseTemplateGenerator.new("principal").call }

  def uploaded(bytes, name: "modelo.docx")
    f = Tempfile.new(["m", ".docx"]); f.binmode; f.write(bytes); f.rewind
    Rack::Test::UploadedFile.new(f.path, "application/vnd.openxmlformats-officedocument.wordprocessingml.document", original_filename: name)
  end

  def add_template(kind: "principal")
    cc.letter_templates.create!(kind: kind, filename: "m.docx", content: docx_bytes)
  end

  def soffice? = system("which soffice > /dev/null 2>&1")

  describe "POST upload de modelo" do
    it "salva um .docx (zip) válido" do
      sign_in admin
      post cost_center_letter_templates_path(cc), params: { kind: "principal", file: uploaded(docx_bytes) }
      expect(response).to redirect_to(cost_center_path(cc))
      expect(cc.letter_templates.principal.first).to be_present
    end

    it "rejeita arquivo que não é docx (sem assinatura zip)" do
      sign_in admin
      post cost_center_letter_templates_path(cc), params: { kind: "principal", file: uploaded("texto qualquer") }
      expect(flash[:alert]).to be_present
      expect(cc.letter_templates).to be_empty
    end

    it "bloqueia gestor" do
      sign_in create(:user, :gestor)
      post cost_center_letter_templates_path(cc), params: { kind: "principal", file: uploaded(docx_bytes) }
      expect(response).to redirect_to(root_path)
    end
  end

  describe "GET geração" do
    it "gera Word (.docx) com os campos preenchidos" do
      add_template
      inv = create(:invoice, cost_center: cc, number: "4501/2026-003", value: 700_000)
      sign_in admin
      get letter_cost_center_path(cc), params: { kind: "principal", invoice_id: inv.id, output: "docx" }
      expect(response).to have_http_status(:ok)
      expect(response.media_type).to include("wordprocessingml")
      txt = document_xml(response.body)
      expect(txt).to include("4501/2026-003")
      expect(txt).to include("CA-#{cc.cr_code}-001/#{Date.current.year}")
      expect(txt).not_to include("{{")
    end

    it "numera o ofício sequencialmente e o preview não consome número" do
      add_template
      sign_in admin

      # Preview não grava nem consome sequência.
      get letter_cost_center_path(cc), params: { kind: "principal", output: "docx", preview: "1" }
      expect(Letter.count).to eq(0)

      get letter_cost_center_path(cc), params: { kind: "principal", output: "docx" }
      get letter_cost_center_path(cc), params: { kind: "principal", output: "docx" }
      expect(Letter.pluck(:number)).to eq(["CA-#{cc.cr_code}-001/#{Date.current.year}",
                                           "CA-#{cc.cr_code}-002/#{Date.current.year}"])
    end

    it "reinicia a sequência a cada ano, por CR (3 dígitos)" do
      Letter.record!(cost_center: cc, kind: "principal", year: 2026)
      Letter.record!(cost_center: cc, kind: "principal", year: 2026)
      expect(Letter.record!(cost_center: cc, kind: "principal", year: 2027).number)
        .to eq("CA-#{cc.cr_code}-001/2027")
    end

    it "sem modelo do tipo → alerta" do
      sign_in admin
      get letter_cost_center_path(cc), params: { kind: "principal", output: "docx" }
      expect(response).to redirect_to(cost_center_path(cc))
      expect(flash[:alert]).to be_present
    end

    # Opt-in: a conversão via LibreOffice é pesada e pode desestabilizar o container
    # de dev compartilhado. Rode com RUN_PDF_SPECS=1. Caminho validado manualmente.
    it "gera PDF e o preview vem inline" do
      skip "defina RUN_PDF_SPECS=1 (e tenha o LibreOffice)" unless soffice? && ENV["RUN_PDF_SPECS"]
      add_template
      inv = create(:invoice, cost_center: cc, value: 700_000)
      sign_in admin
      get letter_cost_center_path(cc), params: { kind: "principal", invoice_id: inv.id, output: "pdf", preview: "1" }
      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("application/pdf")
      expect(response.body[0, 4]).to eq("%PDF")
      expect(response.headers["Content-Disposition"]).to include("inline")
    end

    it "bloqueia coordenador" do
      add_template
      sign_in create(:user, :coordenador)
      get letter_cost_center_path(cc), params: { kind: "principal", output: "docx" }
      expect(response).to redirect_to(root_path)
    end
  end

  describe "GET modelo-base" do
    it "baixa um .docx com os marcadores" do
      sign_in financeiro
      get letter_base_cost_centers_path(kind: "principal")
      expect(response).to have_http_status(:ok)
      expect(response.media_type).to include("wordprocessingml")
      expect(document_xml(response.body)).to include("{{fatura}}")
    end
  end
end
