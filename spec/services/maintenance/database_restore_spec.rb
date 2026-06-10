require "rails_helper"

RSpec.describe Maintenance::DatabaseRestore do
  let(:user) { create(:user, :admin) }

  # Cria um .dump real em backups/ para o BackupList.resolve encontrar.
  def with_dump(name)
    path = Rails.root.join("backups", name)
    FileUtils.mkdir_p(path.dirname)
    File.write(path, "stub-dump")
    yield path
  ensure
    FileUtils.rm_f(path)
  end

  # Evita derrubar a conexão de teste (reconnect!) e a query de verificação.
  def stub_db(select_ok: true)
    conn = ActiveRecord::Base.connection
    allow(conn).to receive(:reconnect!)
    allow(conn).to receive(:execute).and_call_original
    if select_ok
      allow(conn).to receive(:execute).with("SELECT 1").and_return(true)
    else
      allow(conn).to receive(:execute).with("SELECT 1").and_raise(ActiveRecord::StatementInvalid, "down")
    end
  end

  it "monta o pg_restore --clean, valida o banco e registra na auditoria" do
    with_dump("spec_restore.dump") do |path|
      status   = instance_double(Process::Status, exitstatus: 0)
      captured = nil
      allow(Open3).to receive(:capture2e) { |_env, *args| captured = args; ["ok", status] }
      stub_db

      result = nil
      expect {
        result = described_class.new(file: "spec_restore.dump", user: user).call
      }.to change { PaperTrail::Version.where(item_type: "Manutenção", event: "restauração").count }.by(1)

      expect(result).to eq(path)
      expect(captured.first).to eq("pg_restore")
      expect(captured).to include("--clean", "--if-exists", "--no-owner", "--no-privileges")
    end
  end

  it "levanta RestoreError quando o backup não existe" do
    expect {
      described_class.new(file: "naoexiste.dump", user: user).call
    }.to raise_error(described_class::RestoreError, /não encontrado/)
  end

  it "levanta RestoreError quando o banco fica inacessível após o pg_restore" do
    with_dump("spec_restore_fail.dump") do
      status = instance_double(Process::Status, exitstatus: 1)
      allow(Open3).to receive(:capture2e).and_return(["erro", status])
      stub_db(select_ok: false)

      expect {
        described_class.new(file: "spec_restore_fail.dump", user: user).call
      }.to raise_error(described_class::RestoreError, /inacessível/)
    end
  end
end
