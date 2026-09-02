module Reports
  # Monta a árvore de agrupamento (com subtotais em cada nível) usada pelos
  # três relatórios. Recebe linhas planas — cada uma respondendo a um
  # CostCenter — e os níveis desejados (ver Reports::ScopeFilter#levels).
  #
  #   Reports::GroupTree.build(rows, levels: %i[coordenador cliente centro_custo],
  #                            sum_keys: %i[value received balance])
  #   # => { levels:, groups: [nó, ...], totals: { value:, received:, balance:, count: } }
  #
  # Nó (recursivo — mesmo formato consumido pelo PDF e pelo Excel):
  #   { level:, key:, label:, sublabel:, record:, children: [nó...], rows: [...], totals: {} }
  #
  # ATENÇÃO: um CC com mais de um coordenador aparece no grupo de CADA um
  # (fan-out). Por isso o `totals` da RAIZ é calculado sobre as linhas planas,
  # nunca somando os grupos — senão o total geral duplicaria.
  class GroupTree
    NO_COORDINATOR = "Sem Coordenador".freeze
    NO_CLIENT      = "Sem Cliente".freeze
    LAST           = [NO_COORDINATOR, NO_CLIENT].freeze

    def self.build(rows, levels:, sum_keys:, cc_for: ->(row) { row[:cc] })
      new(rows, levels: levels, sum_keys: sum_keys, cc_for: cc_for).call
    end

    def initialize(rows, levels:, sum_keys:, cc_for:)
      @rows     = Array(rows)
      @levels   = Array(levels)
      @sum_keys = Array(sum_keys)
      @cc_for   = cc_for
    end

    def call
      { levels: @levels, groups: build_level(@rows, @levels), totals: totals_for(@rows) }
    end

    private

    def build_level(rows, levels)
      return [flat_node(rows)] if levels.empty?

      level = levels.first
      rest  = levels[1..]

      buckets(rows, level).map do |key, entry|
        node = {
          level:    level,
          key:      key,
          label:    entry[:label],
          sublabel: entry[:sublabel],
          record:   entry[:record],
          children: rest.empty? ? [] : build_level(entry[:rows], rest),
          rows:     rest.empty? ? entry[:rows] : [],
          totals:   totals_for(entry[:rows])
        }
        node
      end
    end

    # Nó implícito para o modo plano (nenhum nível de agrupamento).
    def flat_node(rows)
      { level: :root, key: nil, label: nil, sublabel: nil, record: nil,
        children: [], rows: rows, totals: totals_for(rows) }
    end

    def buckets(rows, level)
      acc = {}

      rows.each do |row|
        cc = @cc_for.call(row)
        entries_for(cc, level).each do |key, label, record, sublabel|
          bucket = (acc[key] ||= { label: label, record: record, sublabel: sublabel, rows: [] })
          bucket[:rows] << row
        end
      end

      acc.sort_by { |_key, entry| sort_key(entry[:label]) }
    end

    # Uma linha pode cair em MAIS DE UM bucket (CC com vários coordenadores).
    def entries_for(cost_center, level)
      case level
      when :coordenador
        names = cost_center&.coordinator_list.presence || [NO_COORDINATOR]
        names.map { |name| [name, name, nil, nil] }
      when :cliente
        client = cost_center&.client
        [[client&.id || :none, client&.name || NO_CLIENT, client, nil]]
      when :centro_custo
        label = [cost_center&.cr_code, cost_center&.description].compact_blank.join(" — ")
        [[cost_center&.id, label, cost_center, cost_center&.client&.name]]
      else
        raise ArgumentError, "nível de agrupamento desconhecido: #{level.inspect}"
      end
    end

    # "Sem Coordenador"/"Sem Cliente" sempre por último; demais em ordem
    # alfabética ignorando acentos.
    def sort_key(label)
      [LAST.include?(label) ? 1 : 0, I18n.transliterate(label.to_s).downcase]
    end

    def totals_for(rows)
      totals = @sum_keys.index_with { |key| rows.sum { |row| row[key] || 0 } }
      totals[:count] = rows.size
      totals
    end
  end
end
