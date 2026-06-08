require 'rails_helper'

RSpec.describe "Dashboard", type: :request do
  describe "GET /" do
    context "unauthenticated" do
      it "redirects to sign in" do
        get root_path
        expect(response).to redirect_to new_user_session_path
      end
    end

    context "as admin" do
      let(:user) { create(:user, :admin) }
      before { sign_in user }

      it "returns 200" do
        get root_path
        expect(response).to have_http_status(:ok)
      end
    end

    context "as financeiro" do
      let(:user) { create(:user, :financeiro) }
      before { sign_in user }

      it "returns 200" do
        get root_path
        expect(response).to have_http_status(:ok)
      end
    end

    context "as gestor" do
      let(:user) { create(:user, :gestor) }
      before { sign_in user }

      it "returns 200 (dashboard is accessible to all roles)" do
        get root_path
        expect(response).to have_http_status(:ok)
      end
    end

    context "as coordenador" do
      let(:user) { create(:user, :coordenador) }
      before { sign_in user }

      it "returns 200" do
        get root_path
        expect(response).to have_http_status(:ok)
      end
    end

    context "oculta zerados nos quadros" do
      let(:user) { create(:user, :admin) }
      before { sign_in user }

      it "não exibe cliente cujos dados estão todos zerados, mas exibe os com valor" do
        zero_cli = create(:client, name: "ZERADO LTDA")
        zero_cc  = create(:cost_center, client: zero_cli, cr_code: "9000")
        create(:forecast_entry, cost_center: zero_cc, month_year: "JUNHO/2026", forecasted_total: 0)

        com_valor = create(:client, name: "COM VALOR SA")
        cc_v      = create(:cost_center, client: com_valor, cr_code: "9001")
        create(:invoice, cost_center: cc_v, issued_at: Date.new(2026, 6, 10), value: 12_345)

        get root_path, params: { month: "2026-06" }
        expect(response.body).not_to include("ZERADO LTDA")
        expect(response.body).to include("COM VALOR SA")
      end

      it "oculta CC quitado no passado e SEM movimento no mês" do
        cli = create(:client, name: "QUITADO ANTIGO")
        cc  = create(:cost_center, client: cli, cr_code: "9100")
        inv = create(:invoice, cost_center: cc, issued_at: Date.new(2026, 5, 5), value: 8_000)
        create(:receipt, invoice: inv, payment_date: Date.new(2026, 5, 20), value: 8_000)

        get root_path, params: { month: "2026-06" }
        expect(response.body).not_to include("QUITADO ANTIGO")
      end

      it "mantém CC com movimento no mês mesmo se quitado (faturado == recebido)" do
        cli = create(:client, name: "PAGO NO MES")
        cc  = create(:cost_center, client: cli, cr_code: "9101")
        inv = create(:invoice, cost_center: cc, issued_at: Date.new(2026, 6, 5), value: 8_000)
        create(:receipt, invoice: inv, payment_date: Date.new(2026, 6, 20), value: 8_000)

        get root_path, params: { month: "2026-06" }
        expect(response.body).to include("PAGO NO MES")
      end
    end

    context "with month filter" do
      let(:user) { create(:user, :admin) }
      before { sign_in user }

      it "returns 200 for valid month param" do
        get root_path, params: { month: "2026-06" }
        expect(response).to have_http_status(:ok)
      end

      it "não quebra com mês inválido (cai no mês atual em vez de 500)" do
        get root_path, params: { month: "'; DROP TABLE invoices; --" }
        expect(response).to have_http_status(:ok)
      end

      it "não quebra com mês malformado" do
        get root_path, params: { month: "2026-99-xx" }
        expect(response).to have_http_status(:ok)
      end
    end
  end
end
