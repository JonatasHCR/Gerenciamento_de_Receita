require "rails_helper"

RSpec.describe Maintenance::DatabaseBackup do
  let(:user)    { create(:user, :admin) }
  let(:service) { described_class.new(user: user) }

  # Captura o caminho passado em -f e simula o pg_dump escrevendo conteúdo nele.
  def fake_pg_dump(success: true, content: "PGDMP-stub")
    captured = nil
    allow(service).to receive(:system) do |_env, *args|
      captured = args
      file = args[args.index("-f") + 1]
      File.write(file, content)
      success
    end
    -> { captured }
  end

  it "gera o dump, retorna o path e registra na auditoria" do
    grab = fake_pg_dump
    path = nil
    expect {
      path = service.call
    }.to change { PaperTrail::Version.where(item_type: "Manutenção", event: "backup").count }.by(1)

    expect(File.exist?(path)).to be(true)
    expect(File.basename(path)).to match(/\Amanual_\d{8}_\d{6}\.dump\z/)
    expect(PaperTrail::Version.where(item_type: "Manutenção", event: "backup").last.whodunnit).to eq(user.id.to_s)
  ensure
    f = grab.call && grab.call[grab.call.index("-f") + 1]
    FileUtils.rm_f(f) if f
  end

  it "monta o comando pg_dump -Fc com os dados de conexão" do
    grab = fake_pg_dump
    service.call
    args = grab.call
    expect(args.first(2)).to eq(["pg_dump", "-Fc"])
    %w[-h -p -U -d -f].each { |flag| expect(args).to include(flag) }
  ensure
    f = grab.call && grab.call[grab.call.index("-f") + 1]
    FileUtils.rm_f(f) if f
  end

  it "levanta BackupError quando o pg_dump retorna falha" do
    grab = fake_pg_dump(success: false)
    expect { service.call }.to raise_error(described_class::BackupError)
    # arquivo parcial é removido
    f = grab.call[grab.call.index("-f") + 1]
    expect(File.exist?(f)).to be(false)
  end

  it "levanta BackupError quando o arquivo sai vazio" do
    fake_pg_dump(content: "")
    expect { service.call }.to raise_error(described_class::BackupError)
  end
end
