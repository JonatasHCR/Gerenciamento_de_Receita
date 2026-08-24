class Adjustment < ApplicationRecord
  has_paper_trail

  belongs_to :cost_center

  # valor: mexe no valor do contrato; prazo: mexe na data final.
  enum :kind, { valor: 0, prazo: 1 }

  attr_accessor :amount

  validates :kind, presence: true
  validates :amount, numericality: { greater_than: 0 }, allow_blank: true
  validates :new_value, presence: true, numericality: { greater_than: 0 }, if: :valor?
  validates :new_date,  presence: true, if: :prazo?
  validate :new_date_not_before_start, if: :prazo?

  before_validation :capture_previous, on: :create
  before_validation :apply_amount
  after_create :apply_to_cost_center
  after_update :resync_cost_center
  after_destroy :revert_from_cost_center

  scope :recent, -> { order(created_at: :desc) }
  scope :chronological, -> { order(:created_at, :id) }

  def value_delta
    return unless valor?
    new_value.to_d - previous_value.to_d
  end

  private

  def apply_amount
    return unless valor? && amount.present?
    self.new_value = previous_value.to_d + amount.to_d
  end

  # Edição de um reajuste: leva a diferença para o CC e reencadeia os
  # reajustes posteriores, pra que o "de → para" do histórico continue batendo.
  def resync_cost_center
    if valor? && saved_change_to_new_value?
      before, after = saved_change_to_new_value
      shift_value_chain(after.to_d - before.to_d)
    elsif prazo? && saved_change_to_new_date?
      resync_end_date
    end
  end

  def revert_from_cost_center
    if valor?
      shift_value_chain(-value_delta)
    elsif prazo?
      resync_end_date
    end
  end

  def shift_value_chain(diff)
    return if diff.zero?
    write_cost_center(value: cost_center.reload.value.to_d + diff)
    siblings.valor
            .where("(adjustments.created_at, adjustments.id) > (?, ?)", created_at, id)
            .update_all(["previous_value = previous_value + ?, new_value = new_value + ?", diff, diff])
  end

  def resync_end_date
    last = siblings.prazo.chronological.last
    write_cost_center(end_date: last&.new_date || previous_date)
  end

  # Grava no CC gerando versão no PaperTrail (auditoria de quem mexeu no
  # contrato); sem validar, pra dado legado de importação não travar o reajuste.
  def write_cost_center(attrs)
    cost_center.assign_attributes(attrs)
    cost_center.save(validate: false)
  end

  def siblings
    Adjustment.where(cost_center_id: cost_center_id)
  end

  def new_date_not_before_start
    return if new_date.blank? || cost_center&.start_date.blank?
    if new_date < cost_center.start_date
      errors.add(:new_date, "não pode ser anterior à data de início do contrato")
    end
  end

  def capture_previous
    if valor?
      self.previous_value = cost_center&.value
    elsif prazo?
      self.previous_date = cost_center&.end_date
    end
  end

  def apply_to_cost_center
    if valor?
      write_cost_center(value: new_value)
    elsif prazo?
      write_cost_center(end_date: new_date)
    end
  end
end
