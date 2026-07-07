class User < ApplicationRecord
  devise :database_authenticatable, :argon2,
         :validatable, :lockable, :timeoutable

  # skip: o hash de senha (argon2) nunca é serializado nas versions — não vaza
  # na auditoria nem fica armazenado no histórico.
  has_paper_trail skip: [:encrypted_password]

  enum :role, { coordenador: 0, gestor: 1, financeiro: 2, admin: 3 }

  has_many :user_cost_centers, dependent: :destroy
  has_many :cost_centers, through: :user_cost_centers

  validates :name, presence: true
  validates :role, presence: true

  # Mantém user_cost_centers em dia com o texto `coordinator` dos CCs: fluxo
  # "CC primeiro, usuário depois" e rename do coordenador sem perder o vínculo.
  after_save :sync_coordinated_cost_centers!, if: :should_sync_cost_centers?

  def admin_or_financeiro?
    admin? || financeiro?
  end

  # Vincula este coordenador aos CCs cujo `coordinator` já cita o nome dele.
  def link_named_cost_centers!
    return if name.blank?
    CostCenter.where("coordinator ILIKE ?", "%#{name}%").find_each do |cc|
      next unless cc.coordinator_list.include?(name)
      cc.user_cost_centers.find_or_create_by!(user: self)
    end
  end

  # Usado pelos checkboxes de CCs no form de Usuário: escreve na string `coordinator`
  # de cada CC e deixa o callback do CostCenter derivar o vínculo.
  def assign_coordinated_cost_centers(ids)
    return if name.blank?
    target_ids  = Array(ids).reject(&:blank?).map(&:to_i)
    current_ids = cost_center_ids

    CostCenter.where(id: target_ids - current_ids).find_each do |cc|
      cc.coordinator_list = (cc.coordinator_list + [name]).uniq
      cc.save!
    end
    CostCenter.where(id: current_ids - target_ids).find_each do |cc|
      cc.coordinator_list = cc.coordinator_list - [name]
      cc.save!
    end
  end

  private

  def should_sync_cost_centers?
    coordenador? && (saved_change_to_name? || saved_change_to_role?)
  end

  def sync_coordinated_cost_centers!
    if saved_change_to_name?
      old_name, new_name = saved_change_to_name
      if old_name.present? && new_name.present?
        cost_centers.to_a.each do |cc|
          list = cc.coordinator_list
          next unless list.include?(old_name)
          cc.coordinator_list = list.map { |n| n == old_name ? new_name : n }
          cc.save!
        end
      end
    end

    link_named_cost_centers!
  end
end
