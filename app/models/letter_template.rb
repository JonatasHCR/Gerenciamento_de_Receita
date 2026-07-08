class LetterTemplate < ApplicationRecord
  belongs_to :cost_center

  # principal = carta de encaminhamento de medição principal; reajuste = variante de reajuste.
  enum :kind, { principal: 0, reajuste: 1 }

  validates :kind, presence: true, uniqueness: { scope: :cost_center_id }
  validates :content, presence: true

  # Aceita .docx (e .doc que na verdade é OOXML/zip). Confere a assinatura ZIP ("PK").
  validate :content_is_docx

  private

  def content_is_docx
    return if content.blank?
    errors.add(:content, "não é um Word (.docx) válido") unless content.to_s.byteslice(0, 2) == "PK"
  end
end
