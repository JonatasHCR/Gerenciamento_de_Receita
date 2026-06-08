module Maintenance
  # Registra ações de manutenção (backup / limpeza) na mesma tabela de auditoria
  # (PaperTrail::Version), para aparecerem na tela /audit_logs.
  module Audit
    ITEM_TYPE = "Manutenção".freeze

    # details: Hash legível { "Rótulo" => "valor" }. Gravado em object_changes no
    # formato [anterior, novo] que a tela de detalhe da auditoria já sabe exibir.
    #
    # Usa insert! para PULAR os callbacks do PaperTrail: o item_type "Manutenção"
    # não é um modelo real, e enforce_version_limit! faria item_type.constantize
    # (NameError). insert! grava direto sem disparar callbacks.
    def self.record(event:, user:, details: {})
      PaperTrail::Version.insert!({
        item_type:      ITEM_TYPE,
        item_id:        0,
        event:          event,
        whodunnit:      user&.id&.to_s,
        object_changes: details.transform_values { |v| [nil, v.to_s] },
        created_at:     Time.current
      })
    end
  end
end
