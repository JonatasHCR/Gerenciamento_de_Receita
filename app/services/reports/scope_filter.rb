module Reports
  # Filtro/agrupamento compartilhado pelos relatórios (movimentação, mensal e
  # compromissos). Traduz os params da tela numa relation de CostCenter já
  # limitada pelo policy_scope, e informa os níveis de agrupamento escolhidos.
  #
  #   Reports::ScopeFilter.from_params(params, scope: policy_scope(CostCenter))
  #
  # Params (vazio = todos, em qualquer dimensão):
  #   group_by            → cliente | centro_custo | coordenador
  #   client_ids[]        → ids de Client
  #   coordinator_names[] → NOMES do texto cost_centers.coordinator
  #   cost_center_ids[]   → ids de CostCenter (é sempre a palavra final)
  class ScopeFilter
    GROUP_BYS        = %i[cliente centro_custo coordenador].freeze
    DEFAULT_GROUP_BY = :cliente

    # Níveis de agrupamento por dimensão. Quando a LINHA do relatório já é o
    # próprio centro de custo (mensal, compromissos), o nível :centro_custo sai
    # — não faz sentido criar um grupo por linha.
    LEVELS = {
      cliente:      %i[cliente centro_custo],
      coordenador:  %i[coordenador cliente centro_custo],
      centro_custo: %i[centro_custo]
    }.freeze

    GROUP_LABELS = {
      cliente: "Cliente", centro_custo: "Centro de Custo", coordenador: "Coordenador"
    }.freeze

    attr_reader :group_by

    def self.from_params(params, scope:, default_group_by: DEFAULT_GROUP_BY)
      new(
        scope:             scope,
        group_by:          params[:group_by],
        client_ids:        params[:client_ids],
        coordinator_names: params[:coordinator_names],
        cost_center_ids:   params[:cost_center_ids],
        default_group_by:  default_group_by
      )
    end

    def initialize(scope:, group_by: nil, client_ids: nil, coordinator_names: nil,
                   cost_center_ids: nil, default_group_by: DEFAULT_GROUP_BY)
      @scope             = scope
      @client_ids        = int_list(client_ids)
      @coordinator_names = str_list(coordinator_names)
      @cost_center_ids   = int_list(cost_center_ids)

      requested = group_by.presence&.to_sym
      @group_by = GROUP_BYS.include?(requested) ? requested : default_group_by
    end

    # Relation final (use como SUBQUERY: .select(:id)) — já com policy_scope.
    def cost_centers
      @cost_centers ||= begin
        rel = selectable_cost_centers
        rel = rel.where(id: @cost_center_ids) if @cost_center_ids.present?
        rel
      end
    end

    # Sem o recorte de cost_center_ids — alimenta o seletor de CCs na tela.
    def selectable_cost_centers
      @selectable_cost_centers ||= begin
        rel = @scope
        rel = rel.where(client_id: @client_ids)                    if @client_ids.present?
        rel = rel.coordinated_by_names(@coordinator_names)         if @coordinator_names.present?
        rel
      end
    end

    # Níveis para o Reports::GroupTree.
    def levels(row_is_cost_center: false)
      list = LEVELS.fetch(@group_by)
      row_is_cost_center ? list - [:centro_custo] : list
    end

    def selected_client_ids        = @client_ids
    def selected_coordinator_names = @coordinator_names
    def selected_cost_center_ids   = @cost_center_ids

    def filtered?
      @client_ids.present? || @coordinator_names.present? || @cost_center_ids.present?
    end

    # Texto do filtro aplicado, para o cabeçalho do PDF/Excel.
    def label
      parts = ["Agrupado por #{GROUP_LABELS.fetch(@group_by)}"]
      parts << "#{@client_ids.size} cliente(s)"          if @client_ids.present?
      parts << "coordenador(es): #{@coordinator_names.join(', ')}" if @coordinator_names.present?
      parts << "#{@cost_center_ids.size} centro(s) de custo" if @cost_center_ids.present?
      parts.join(" · ")
    end

    # Opções dos seletores, restritas ao que o usuário pode ver.
    def self.client_options(scope)
      Client.where(id: scope.reselect(:client_id)).order(:name)
    end

    def self.coordinator_options(scope)
      scope.reselect(:coordinator).distinct.pluck(:coordinator)
           .flat_map { |c| c.to_s.split("/").map(&:strip) }
           .reject(&:blank?).uniq
           .sort_by { |n| I18n.transliterate(n).downcase }
    end

    private

    def int_list(values)
      Array(values).reject(&:blank?).map(&:to_i)
    end

    def str_list(values)
      Array(values).map { |v| v.to_s.strip }.reject(&:blank?)
    end
  end
end
