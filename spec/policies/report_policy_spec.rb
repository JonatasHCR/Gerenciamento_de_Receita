require 'rails_helper'

RSpec.describe ReportPolicy, type: :policy do
  subject(:policy) { described_class.new(user, :report) }

  context "when admin" do
    let(:user) { build(:user, :admin) }
    it { is_expected.to permit_action(:monthly) }
  end

  context "when financeiro" do
    let(:user) { build(:user, :financeiro) }
    it { is_expected.to permit_action(:monthly) }
  end

  context "when gestor" do
    let(:user) { build(:user, :gestor) }
    it { is_expected.not_to permit_action(:monthly) }
  end

  context "when coordenador" do
    let(:user) { build(:user, :coordenador) }
    it { is_expected.not_to permit_action(:monthly) }
  end
end
