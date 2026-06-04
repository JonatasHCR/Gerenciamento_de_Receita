require 'rails_helper'

RSpec.describe InvoicePolicy, type: :policy do
  subject(:policy) { described_class.new(user, invoice) }

  let(:invoice) { build(:invoice) }

  context "when admin" do
    let(:user) { build(:user, :admin) }
    it { is_expected.to permit_action(:index) }
    it { is_expected.to permit_action(:create) }
    it { is_expected.to permit_action(:destroy) }
  end

  context "when financeiro" do
    let(:user) { build(:user, :financeiro) }
    it { is_expected.to permit_action(:index) }
    it { is_expected.to permit_action(:create) }
    it { is_expected.not_to permit_action(:destroy) }
  end

  context "when gestor" do
    let(:user) { build(:user, :gestor) }
    it { is_expected.not_to permit_action(:index) }
    it { is_expected.not_to permit_action(:create) }
  end

  context "when coordenador" do
    let(:user) { build(:user, :coordenador) }
    it { is_expected.not_to permit_action(:index) }
    it { is_expected.not_to permit_action(:create) }
  end
end
