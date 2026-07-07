require "rails_helper"
require "caxlsx"

RSpec.describe Imports::UserImporter do
  def build_xlsx(rows, header: ["NOME", "EMAIL", "PAPEL", "SENHA"])
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

  it "cria usuário novo com senha e papel" do
    path = build_xlsx([["Novo Coordenador", "novo.coord@teste.com", "coordenador", "senha123456"]])
    result = described_class.new(path).call

    expect(result.created).to eq(1)
    u = User.find_by(email: "novo.coord@teste.com")
    expect(u.name).to eq("Novo Coordenador")
    expect(u.coordenador?).to be true
    expect(u.valid_password?("senha123456")).to be true
  end

  it "atualiza usuário existente por email (senha só se preenchida)" do
    existing = create(:user, :coordenador, email: "existente@teste.com", name: "Antigo",
                      password: "originalpass", password_confirmation: "originalpass")
    path = build_xlsx([["Nome Atualizado", "existente@teste.com", "gestor", ""]])
    result = described_class.new(path).call

    expect(result.updated).to eq(1)
    existing.reload
    expect(existing.name).to eq("Nome Atualizado")
    expect(existing.gestor?).to be true
    expect(existing.valid_password?("originalpass")).to be true
  end

  it "sinaliza erro quando usuário novo vem sem senha" do
    path = build_xlsx([["Sem Senha", "sem.senha@teste.com", "coordenador", ""]])
    result = described_class.new(path).call

    expect(result.created).to eq(0)
    expect(User.find_by(email: "sem.senha@teste.com")).to be_nil
    expect(result.errors.join).to match(/senha é obrigatória/)
  end

  it "sinaliza papel inválido" do
    path = build_xlsx([["Fulano", "papel.ruim@teste.com", "chefe", "senha123456"]])
    result = described_class.new(path).call

    expect(result.created).to eq(0)
    expect(result.errors.join).to match(/papel inválido/)
  end
end
