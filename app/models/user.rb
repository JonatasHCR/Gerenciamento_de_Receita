class User < ApplicationRecord
  # Autenticação é do Keycloak. Saíram:
  #   :database_authenticatable — não há senha local para verificar
  #   :argon2                   — não há hash para calcular
  #   :lockable                 — bloqueio por tentativas virou bruteForceProtected
  #                               no realm; failed_attempts/locked_at/unlock_token
  #                               ficaram como colunas mortas
  #   :validatable              — ele valida `password` (`validates_length_of
  #                               :password, allow_blank: true`), e sem o
  #                               :database_authenticatable esse atributo não
  #                               existe: NoMethodError em todo save. As
  #                               validações de email que ele dava estão
  #                               explícitas abaixo.
  # :timeoutable fica, pela expiração de sessão ociosa.
  devise :omniauthable, :timeoutable, omniauth_providers: [:keycloak]

  # skip: o hash de senha nunca foi serializado nas versions — não vaza na
  # auditoria nem fica no histórico. A coluna continua existindo (sem uso) para
  # não reescrever linhas antigas.
  has_paper_trail skip: [:encrypted_password]

  enum :role, { coordenador: 0, gestor: 1, financeiro: 2, admin: 3 }

  has_many :user_cost_centers, dependent: :destroy
  has_many :cost_centers, through: :user_cost_centers

  validates :name, presence: true
  validates :role, presence: true
  # O que o :validatable garantia, agora explícito.
  validates :email, presence: true,
                    uniqueness: { case_sensitive: false },
                    format: { with: URI::MailTo::EMAIL_REGEXP, allow_blank: true }

  # O `sub` do Keycloak (UUID). É o vínculo estável entre a conta local e a
  # identidade: no primeiro login o usuário é achado por email e este campo é
  # gravado; daí em diante o casamento é por aqui. Preserva o id, e com ele o
  # PaperTrail e os user_cost_centers.
  validates :external_id, uniqueness: true, allow_nil: true

  # Mantém user_cost_centers em dia com o texto `coordinator` dos CCs: fluxo
  # "CC primeiro, usuário depois" e rename do coordenador sem perder o vínculo.
  after_save :sync_coordinated_cost_centers!, if: :should_sync_cost_centers?

  # Devise chama isto em TODA requisição, não só no login: quem for desativado
  # perde a sessão em aberto na requisição seguinte, sem precisar deslogar.
  #
  # `ativo` espelha o grupo `/apps/receita` do Keycloak. É a defesa para o caso
  # de alguém tentar acessar direto, com uma sessão que ainda não expirou.
  def active_for_authentication?
    super && ativo?
  end

  def inactive_message
    ativo? ? super : :nao_tem_acesso
  end

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
