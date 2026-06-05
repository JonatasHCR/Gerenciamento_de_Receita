require 'rails_helper'

RSpec.describe CostCenter, type: :model do
  describe "validations" do
    subject { build(:cost_center) }
    it { is_expected.to validate_presence_of(:cr_code) }
    it { is_expected.to validate_presence_of(:description) }
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
