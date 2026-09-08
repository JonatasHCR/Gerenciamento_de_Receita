require "rails_helper"
require "caxlsx"

RSpec.describe Imports::UserImporter do
  def build_xlsx(rows, header: ["NOME", "EMAIL", "PAPEL"])
    pkg = Axlsx::Package.new
    pkg.workbook.add_worksheet(name: "USUARIOS") do |s|
      s.add_row ["USUARIOS"]; s.add_row []; s.add_row []
      s.add_row header
      rows.each { |r| s.add_row(r) }
    end
    path = Rails.root.join("tmp", "user_import_#{SecureRandom.hex(4)}.xlsx").to_s
    pkg.serialize(path)
    path
  end

  after { Dir.glob(Rails.root.join("tmp", "user_import_*.xlsx")).each { |f| File.delete(f) } }

  it "cria usuário novo com papel, sem senha" do
    path = build_xlsx([["Novo Coordenador", "novo.coord@teste.com", "coordenador"]])
    result = described_class.new(path).call

    expect(result.created).to eq(1)
    u = User.find_by(email: "novo.coord@teste.com")
    expect(u.name).to eq("Novo Coordenador")
    expect(u.coordenador?).to be true
    # A importação define só o PAPEL. Para entrar, a pessoa precisa existir no
    # Keycloak e no grupo /apps/receita — o vínculo é feito no primeiro login.
    expect(u.external_id).to be_nil
  end

  it "atualiza usuário existente por email" do
    existing = create(:user, :coordenador, email: "existente@teste.com", name: "Antigo")
    path = build_xlsx([["Nome Atualizado", "existente@teste.com", "gestor"]])
    result = described_class.new(path).call

    expect(result.updated).to eq(1)
    existing.reload
    expect(existing.name).to eq("Nome Atualizado")
    expect(existing.gestor?).to be true
  end

  it "aceita planilha antiga que ainda traz a coluna SENHA, ignorando-a" do
    # Arquivos com o cabeçalho antigo continuam circulando; quebrar neles seria
    # gratuito, já que a coluna simplesmente não tem mais uso.
    path = build_xlsx([["Com Coluna Velha", "velha@teste.com", "coordenador", "senha123456"]],
                      header: ["NOME", "EMAIL", "PAPEL", "SENHA"])
    result = described_class.new(path).call

    expect(result.created).to eq(1)
    expect(User.find_by(email: "velha@teste.com")).to be_present
  end

  it "sinaliza papel inválido" do
    path = build_xlsx([["Fulano", "papel.ruim@teste.com", "chefe"]])
    result = described_class.new(path).call

    expect(result.created).to eq(0)
    expect(result.errors.join).to match(/papel inválido/)
  end
end
