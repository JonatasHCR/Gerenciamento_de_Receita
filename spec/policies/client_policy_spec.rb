require 'rails_helper'

RSpec.describe ClientPolicy, type: :policy do
  subject(:policy) { described_class.new(user, client) }

  let(:client) { build(:client) }

  context "when admin" do
    let(:user) { build(:user, :admin) }
    it { is_expected.to permit_action(:index) }
    it { is_expected.to permit_action(:create) }
    it { is_expected.to permit_action(:update) }
    it { is_expected.to permit_action(:destroy) }
  end

  context "when financeiro" do
    let(:user) { build(:user, :financeiro) }
    it { is_expected.to permit_action(:index) }
    it { is_expected.to permit_action(:create) }
    it { is_expected.to permit_action(:update) }
    it { is_expected.not_to permit_action(:destroy) }
  end

  context "when gestor" do
    let(:user) { build(:user, :gestor) }
    it { is_expected.to permit_action(:index) }
    it { is_expected.to permit_action(:show) }
    it { is_expected.not_to permit_action(:create) }
    it { is_expected.not_to permit_action(:destroy) }
  end

  context "when coordenador" do
    let(:user) { build(:user, :coordenador) }
    it { is_expected.to permit_action(:index) }
    it { is_expected.to permit_action(:show) }
    it { is_expected.not_to permit_action(:create) }
    it { is_expected.not_to permit_action(:destroy) }
  end
end
