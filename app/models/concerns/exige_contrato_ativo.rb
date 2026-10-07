# Contrato desativado continua existindo, mas não aceita lançamento novo nem
# alteração: NF, recebimento, previsão e reajuste. Vale para a tela e para a
# importação, que passam pela mesma validação.
module ExigeContratoAtivo
  extend ActiveSupport::Concern

  included do
    validate :contrato_ativo, on: %i[create update]
  end

  private

  def contrato_ativo
    contrato = contrato_do_lancamento
    return if contrato.nil? || contrato.active?

    errors.add(:base, "O contrato #{contrato.cr_code} está desativado e não aceita lançamentos. " \
                      "Reative o contrato para cadastrar ou alterar.")
  end

  def contrato_do_lancamento
    cost_center
  end
end
