class CostCenter < ApplicationRecord
  has_paper_trail

  belongs_to :client
  has_many :user_cost_centers, dependent: :destroy
  has_many :users, through: :user_cost_centers
  has_many :invoices, dependent: :restrict_with_error
  has_many :forecast_entries, dependent: :destroy
  has_many :adjustments, dependent: :destroy
  has_many :letter_templates, dependent: :destroy
  has_many :letters, dependent: :destroy

  def letter_template_for(kind)
    letter_templates.find_by(kind: kind)
  end

  # Deriva os vínculos (user_cost_centers) do campo texto `coordinator`.
  after_save :sync_coordinator_links!, if: :saved_change_to_coordinator?

  validates :cr_code, presence: true, uniqueness: true
  validates :description, presence: true
  validates :participation, presence: true,
            numericality: { greater_than: 0, less_than_or_equal_to: 1 }
  validate :end_date_not_before_start_date

  scope :ordered, -> { order(:cr_code) }

  # Um CC pode ter mais de um coordenador/gestor. Armazenado no campo string
  # `coordinator` com os nomes separados por " / " (mesmo formato da planilha).
  COORDINATOR_SEP = " / ".freeze

  def coordinator_list
    coordinator.to_s.split("/").map(&:strip).reject(&:blank?)
  end

  def coordinator_list=(values)
    self.coordinator = Array(values).map { |v| v.to_s.strip }.reject(&:blank?).join(COORDINATOR_SEP)
  end

  # Participação informada/exibida em percentual (0 a 100), armazenada como
  # decimal (0 a 1,0) no banco.
  def participation_percent
    return nil if participation.nil?
    pct = participation * 100
    pct == pct.to_i ? pct.to_i : pct
  end

  def participation_percent=(value)
    self.participation = value.present? ? (value.to_d / 100) : nil
  end

  def end_date_not_before_start_date
    return if start_date.blank? || end_date.blank?
    if end_date < start_date
      errors.add(:end_date, "não pode ser anterior à data de início (#{start_date.strftime('%d/%m/%Y')})")
    end
  end

  # Total faturado considerando apenas NFs PRINCIPAIS (reajustes não entram).
  def principal_invoiced
    invoices.principal.sum(:value)
  end

  # Saldo (TOTAL do contrato) = valor do contrato − faturado principal.
  def saldo
    (value || 0) - principal_invoiced
  end

  # Valor do contrato que cabe à UFC (aplica a participação).
  def value_ufc
    (value || 0) * (participation || 0)
  end

  # Saldo que cabe à UFC (aplica a participação). 100% → saldo total.
  def saldo_ufc
    saldo * (participation || 0)
  end

  # % a executar = saldo em relação ao valor do contrato (0 a 100, 2 casas).
  def percent_to_execute
    return 0 if value.to_f.zero?
    (saldo / value * 100).round(2)
  end

  # Reconcilia user_cost_centers com os coordenadores (User de papel coordenador)
  # nomeados no texto `coordinator`. Público para reuso no backfill.
  def sync_coordinator_links!
    names   = coordinator_list
    matched = names.empty? ? User.none : User.coordenador.where(name: names)

    matched.where.not(id: users.select(:id)).find_each do |u|
      user_cost_centers.create!(user: u)
    end

    user_cost_centers.where(user: User.coordenador)
                     .where.not(user_id: matched.pluck(:id))
                     .destroy_all
  end
end
