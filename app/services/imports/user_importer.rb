require "roo"

module Imports
  # Importa usuários da aba USUARIOS (NOME, EMAIL, PAPEL, SENHA). Só admin usa.
  # Upsert por email: novo exige senha; existente atualiza nome/papel (senha só se vier).
  class UserImporter
    Result = Imports::ExcelImporter::Result

    SHEET   = "USUARIOS".freeze
    COLUMNS = { name: %w[NOME], email: %w[EMAIL], role: %w[PAPEL PERFIL ROLE], password: %w[SENHA] }.freeze
    ROLES   = { "COORDENADOR" => :coordenador, "GESTOR" => :gestor,
                "FINANCEIRO" => :financeiro, "ADMIN" => :admin }.freeze

    def initialize(file_path)
      @file_path = file_path
      @errors    = []
      @created   = 0
      @updated   = 0
    end

    def call
      sheet = open_sheet(Roo::Spreadsheet.open(@file_path.to_s))
      return Result.new(created: @created, updated: @updated, errors: @errors, fatal_error: nil) unless sheet

      header_row, idx = detect_columns(sheet)
      if header_row.nil?
        @errors << "Aba \"#{SHEET}\": cabeçalho não reconhecido (esperado NOME, EMAIL, PAPEL, SENHA)."
        return Result.new(created: @created, updated: @updated, errors: @errors, fatal_error: nil)
      end

      (header_row + 1).upto(sheet.last_row || 0) do |line|
        row = sheet.row(line)
        next if row.nil?
        upsert_user(row, idx, line)
      end

      Result.new(created: @created, updated: @updated, errors: @errors, fatal_error: nil)
    rescue => e
      Result.new(created: @created, updated: @updated, errors: @errors,
                 fatal_error: "Não foi possível processar o arquivo: #{e.message}")
    end

    private

    def open_sheet(wb)
      wb.sheet(SHEET)
    rescue
      @errors << "Aba \"#{SHEET}\" não encontrada na planilha."
      nil
    end

    def detect_columns(sheet)
      max = [sheet.last_row || 0, 20].min
      (1..max).each do |r|
        headers = sheet.row(r).map { |c| norm(c) }
        next unless headers.any? { |h| h == "EMAIL" }

        idx = {}
        COLUMNS.each do |key, syns|
          idx[key] = headers.index { |h| syns.include?(h) }
        end
        return [r, idx]
      end
      [nil, {}]
    end

    def upsert_user(row, idx, line)
      email = val(row, idx[:email]).downcase
      name  = val(row, idx[:name])
      return if email.blank? && name.blank?

      if email.blank?
        @errors << "Usuários — linha #{line} (#{name}): e-mail é obrigatório."
        return
      end

      user    = User.find_or_initialize_by(email: email)
      was_new = user.new_record?

      user.name = name if name.present?

      role = parse_role(val(row, idx[:role]))
      if role
        user.role = role
      elsif val(row, idx[:role]).present?
        @errors << "Usuários — linha #{line} (#{email}): papel inválido (use coordenador/gestor/financeiro/admin)."
        return
      end

      password = val(row, idx[:password])
      if was_new && password.blank?
        @errors << "Usuários — linha #{line} (#{email}): senha é obrigatória para novo usuário (mín. 6)."
        return
      end
      user.password = password if password.present?

      return unless was_new || user.changed?

      user.save!
      was_new ? @created += 1 : @updated += 1
    rescue => e
      @errors << "Usuários — linha #{line} (#{email}): #{e.message}"
    end

    def parse_role(text)
      ROLES[norm(text)]
    end

    def val(row, i)
      i ? row[i].to_s.strip : ""
    end

    def norm(value)
      value.to_s.unicode_normalize(:nfkd).gsub(/\p{Mn}/, "").upcase.strip
    end
  end
end
