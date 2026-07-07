require 'rails_helper'

RSpec.describe User, type: :model do
  subject(:user) { build(:user) }

  describe "validations" do
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_presence_of(:email) }
  end

  describe "associations" do
    it { is_expected.to have_many(:user_cost_centers).dependent(:destroy) }
    it { is_expected.to have_many(:cost_centers).through(:user_cost_centers) }
  end

  describe "roles" do
    it "defaults to coordenador" do
      expect(build(:user).role).to eq("coordenador")
    end

    it { is_expected.to define_enum_for(:role).with_values(coordenador: 0, gestor: 1, financeiro: 2, admin: 3) }
  end

  describe "vínculo com centros de custo" do
    it "vincula ao ser criado depois do CC que já cita seu nome (fluxo 'CC primeiro')" do
      cc = create(:cost_center, coordinator: "Pedro Souza")
      expect(cc.users).to be_empty

      u = create(:user, :coordenador, name: "Pedro Souza")
      expect(u.cost_centers).to include(cc)
    end

    it "preserva o vínculo e atualiza a string ao renomear o coordenador" do
      u   = create(:user, :coordenador, name: "João Antigo")
      cc1 = create(:cost_center, coordinator: "João Antigo")
      cc2 = create(:cost_center, coordinator: "João Antigo / Externo XYZ")
      expect(cc1.users).to include(u)
      expect(cc2.users).to include(u)

      u.update!(name: "João Novo")

      expect(cc1.reload.users).to include(u)
      expect(cc2.reload.users).to include(u)
      expect(cc1.coordinator_list).to eq(["João Novo"])
      expect(cc2.coordinator_list).to eq(["João Novo", "Externo XYZ"])
    end

    it "#assign_coordinated_cost_centers adiciona e remove vínculos pela string" do
      u    = create(:user, :coordenador, name: "Marta Lima")
      cc_a = create(:cost_center, coordinator: "Outro Coord")
      cc_b = create(:cost_center, coordinator: "Marta Lima")
      expect(u.reload.cost_centers).to contain_exactly(cc_b)

      u.assign_coordinated_cost_centers([cc_a.id])

      expect(u.reload.cost_centers).to contain_exactly(cc_a)
      expect(cc_a.reload.coordinator_list).to include("Marta Lima")
      expect(cc_b.reload.coordinator_list).not_to include("Marta Lima")
    end
  end

  describe "#admin_or_financeiro?" do
    it "returns true for admin" do
      expect(build(:user, :admin).admin_or_financeiro?).to be true
    end

    it "returns true for financeiro" do
      expect(build(:user, :financeiro).admin_or_financeiro?).to be true
    end

    it "returns false for coordenador" do
      expect(build(:user).admin_or_financeiro?).to be false
    end
  end
end
