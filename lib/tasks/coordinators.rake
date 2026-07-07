# Backfill dos vínculos coordenador↔CC a partir do texto `coordinator` dos CCs.
# Necessário uma vez após introduzir a derivação automática (dados importados de
# Excel têm o nome do coordenador, mas nenhum user_cost_center).
#   docker compose exec web bin/rails coordinators:sync
namespace :coordinators do
  desc "Reconcilia user_cost_centers a partir do campo coordinator de cada CC"
  task sync: :environment do
    before = UserCostCenter.count
    CostCenter.find_each(&:sync_coordinator_links!)
    puts "✅ Vínculos reconciliados: #{before} → #{UserCostCenter.count}"
  end
end
