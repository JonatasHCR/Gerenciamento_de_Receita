require 'rails_helper'

RSpec.describe CostCenter, type: :model do
  describe "validations" do
    subject { build(:cost_center) }
    it { is_expected.to validate_presence_of(:cr_code) }
    it { is_expected.to validate_presence_of(:description) }
  end

  describe "datas do contrato" do
    it "não aceita data final anterior à data de início" do
      cc = build(:cost_center, start_date: Date.new(2026, 6, 1), end_date: Date.new(2026, 1, 1))
      expect(cc).not_to be_valid
      expect(cc.errors[:end_date]).to be_present
    end

    it "aceita data final igual ou posterior ao início" do
      expect(build(:cost_center, start_date: Date.new(2026, 1, 1), end_date: Date.new(2026, 12, 31))).to be_valid
    end
  end

  describe "saldo e % a executar (faturamento principal)" do
    let(:cc) { create(:cost_center, value: 100_000) }

    it "saldo = valor − faturado principal (ignora reajustes)" do
      create(:invoice, cost_center: cc, value: 30_000, kind: :principal)
      create(:invoice, cost_center: cc, value: 10_000, kind: :reajuste)
      expect(cc.principal_invoiced).to eq(30_000)
      expect(cc.saldo).to eq(70_000)
    end

    it "% a executar = saldo/valor*100 com 2 casas" do
      create(:invoice, cost_center: cc, value: 25_000, kind: :principal)
      expect(cc.percent_to_execute).to eq(75.0)
    end

    it "% a executar é 0 quando valor é zero" do
      expect(build(:cost_center, value: 0).percent_to_execute).to eq(0)
    end
  end

  describe "valores UFC (participação aplicada)" do
    it "100% → saldo/valor UFC iguais ao total" do
      cc = create(:cost_center, value: 100_000, participation: 1.0)
      create(:invoice, cost_center: cc, value: 30_000, kind: :principal)
      expect(cc.value_ufc).to eq(100_000)
      expect(cc.saldo_ufc).to eq(70_000)
    end

    it "50% → metade do valor e do saldo" do
      cc = create(:cost_center, value: 100_000, participation: 0.5)
      create(:invoice, cost_center: cc, value: 30_000, kind: :principal)
      expect(cc.value_ufc).to eq(50_000)
      expect(cc.saldo_ufc).to eq(35_000) # (100k - 30k) * 0,5
    end
  end

  describe "coordinator_list (múltiplos coordenadores/gestores)" do
    it "divide a string por '/' em uma lista" do
      cc = build(:cost_center, coordinator: "Ana / Dr. João / Beltrano")
      expect(cc.coordinator_list).to eq(["Ana", "Dr. João", "Beltrano"])
    end

    it "junta a lista com ' / ' ignorando vazios" do
      cc = build(:cost_center)
      cc.coordinator_list = ["Ana", "", "  ", "João"]
      expect(cc.coordinator).to eq("Ana / João")
    end

    it "retorna lista vazia quando não há coordenador" do
      expect(build(:cost_center, coordinator: nil).coordinator_list).to eq([])
    end
  end

  describe "vínculo coordenador↔CC derivado do campo coordinator" do
    it "cria o vínculo para User coordenador nomeado" do
      u  = create(:user, :coordenador, name: "Carlos Almeida")
      cc = create(:cost_center, coordinator: "Carlos Almeida")
      expect(cc.users).to include(u)
    end

    it "não vincula nome sem User (coordenador externo)" do
      cc = create(:cost_center, coordinator: "Construtora Externa XYZ")
      expect(cc.users).to be_empty
    end

    it "não vincula usuário que não é coordenador" do
      create(:user, :gestor, name: "Fulano Gestor")
      cc = create(:cost_center, coordinator: "Fulano Gestor")
      expect(cc.users).to be_empty
    end

    it "remove o vínculo ao retirar o nome do coordinator" do
      u  = create(:user, :coordenador, name: "Ana Pereira")
      cc = create(:cost_center, coordinator: "Ana Pereira")
      expect(cc.users).to include(u)

      cc.update!(coordinator: "Outra Pessoa")
      expect(cc.reload.users).to be_empty
    end
  end

  describe "participation_percent" do
    it "converte percentual (0–100) para decimal (0–1) ao atribuir" do
      cc = build(:cost_center, participation_percent: 50)
      expect(cc.participation).to eq(0.5)
    end

    it "trata 100% como 1.0" do
      cc = build(:cost_center, participation_percent: 100)
      expect(cc.participation).to eq(1.0)
    end

    it "aceita percentuais fracionados" do
      cc = build(:cost_center, participation_percent: 12.5)
      expect(cc.participation).to eq(0.125)
    end

    it "expõe o decimal armazenado como percentual inteiro quando exato" do
      expect(build(:cost_center, participation: 0.5).participation_percent).to eq(50)
      expect(build(:cost_center, participation: 1.0).participation_percent).to eq(100)
    end

    it "retorna nil quando participation é nil" do
      expect(build(:cost_center, participation: nil).participation_percent).to be_nil
    end
  end
end
