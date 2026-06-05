require 'rails_helper'

RSpec.describe CostCenter, type: :model do
  describe "validations" do
    subject { build(:cost_center) }
    it { is_expected.to validate_presence_of(:cr_code) }
    it { is_expected.to validate_presence_of(:description) }
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
