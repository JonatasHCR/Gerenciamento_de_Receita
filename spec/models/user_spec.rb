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
