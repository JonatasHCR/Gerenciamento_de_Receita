require 'rails_helper'

RSpec.describe Reports::ScopeFilter do
  let(:client_a) { create(:client, name: "AAA Cliente") }
  let(:client_b) { create(:client, name: "BBB Cliente") }

  # Coordenador B tem 2 CCs; o exemplo do usuário é filtrar por ele e marcar só 1.
  let!(:cc1) { create(:cost_center, client: client_a, cr_code: "SF-1", coordinator: "Bruno Lima") }
  let!(:cc2) { create(:cost_center, client: client_b, cr_code: "SF-2", coordinator: "Bruno Lima / Ana Souza") }
  let!(:cc3) { create(:cost_center, client: client_b, cr_code: "SF-3", coordinator: "Ana Souza") }

  # Escopo restrito aos CCs do próprio exemplo — o banco de teste pode ter
  # resíduo de outras suítes.
  let(:scope) { CostCenter.where(id: [cc1.id, cc2.id, cc3.id]) }

  def filter(params = {}, scope: self.scope, **opts)
    described_class.from_params(ActionController::Parameters.new(params).permit!, scope: scope, **opts)
  end

  it "sem params devolve todo o escopo e o agrupamento padrão" do
    f = filter({})
    expect(f.group_by).to eq(:cliente)
    expect(f.cost_centers).to match_array([cc1, cc2, cc3])
  end

  it "cai no default quando group_by é inválido" do
    expect(filter({ group_by: "banana" }).group_by).to eq(:cliente)
    expect(filter({}, default_group_by: :centro_custo).group_by).to eq(:centro_custo)
  end

  it "filtra por cliente" do
    expect(filter({ client_ids: [client_b.id] }).cost_centers).to match_array([cc2, cc3])
  end

  it "filtra por nome de coordenador, inclusive quando o CC tem vários" do
    expect(filter({ coordinator_names: ["Bruno Lima"] }).cost_centers).to match_array([cc1, cc2])
    expect(filter({ coordinator_names: ["Ana Souza"] }).cost_centers).to match_array([cc2, cc3])
  end

  it "casa o nome do coordenador por igualdade, não por trecho" do
    cc4 = create(:cost_center, cr_code: "SF-4", coordinator: "Ana Souza Filha")
    wider = CostCenter.where(id: [cc1.id, cc2.id, cc3.id, cc4.id])
    expect(filter({ coordinator_names: ["Ana Souza"] }, scope: wider).cost_centers).to match_array([cc2, cc3])
  end

  it "funciona com coordenador externo (sem usuário cadastrado)" do
    expect(User.where(name: "Bruno Lima")).to be_empty
    expect(filter({ coordinator_names: ["Bruno Lima"] }).cost_centers).to match_array([cc1, cc2])
  end

  it "a seleção de centro de custo é a palavra final dentro do coordenador" do
    f = filter({ coordinator_names: ["Bruno Lima"], cost_center_ids: [cc1.id] })
    expect(f.cost_centers).to match_array([cc1])
  end

  it "interseção vazia quando o CC marcado não é do coordenador" do
    f = filter({ coordinator_names: ["Bruno Lima"], cost_center_ids: [cc3.id] })
    expect(f.cost_centers).to be_empty
  end

  it "trata o hidden field vazio como 'nenhum filtro'" do
    f = filter({ client_ids: [""], coordinator_names: [""], cost_center_ids: [""] })
    expect(f).not_to be_filtered
    expect(f.cost_centers).to match_array([cc1, cc2, cc3])
  end

  it "respeita o policy_scope do coordenador, sem duplicar" do
    user = create(:user, :coordenador, name: "Bruno Lima")
    cc1.sync_coordinator_links!
    cc2.sync_coordinator_links!

    scope = CostCenterPolicy::Scope.new(user, CostCenter).resolve
    f = filter({ coordinator_names: ["Bruno Lima"] }, scope: scope)
    expect(f.cost_centers.to_a).to match_array([cc1, cc2])
  end

  describe "#levels" do
    it "monta a hierarquia por dimensão" do
      expect(filter({ group_by: "cliente" }).levels).to eq(%i[cliente centro_custo])
      expect(filter({ group_by: "coordenador" }).levels).to eq(%i[coordenador cliente centro_custo])
      expect(filter({ group_by: "centro_custo" }).levels).to eq(%i[centro_custo])
    end

    it "remove o nível de CC quando a própria linha já é o CC" do
      expect(filter({ group_by: "coordenador" }).levels(row_is_cost_center: true)).to eq(%i[coordenador cliente])
      expect(filter({ group_by: "centro_custo" }).levels(row_is_cost_center: true)).to eq([])
    end
  end

  describe "opções dos seletores" do
    it "lista clientes e coordenadores do escopo" do
      expect(described_class.client_options(scope)).to match_array([client_a, client_b])
      expect(described_class.coordinator_options(scope)).to eq(["Ana Souza", "Bruno Lima"])
    end
  end
end
