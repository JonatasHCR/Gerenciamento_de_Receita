require "rails_helper"

RSpec.describe "Security headers (CSP)", type: :request do
  it "envia o header Content-Security-Policy com as travas principais" do
    get new_user_session_path
    csp = response.headers["Content-Security-Policy"]

    expect(csp).to be_present
    expect(csp).to include("default-src 'self'")
    expect(csp).to include("object-src 'none'")
    expect(csp).to include("base-uri 'self'")
    expect(csp).to include("frame-ancestors 'self'")
    # script-src usa nonce (sem unsafe-inline)
    expect(csp).to match(/script-src 'self' 'nonce-/)
    expect(csp).not_to match(/script-src[^;]*unsafe-inline/)
  end

  it "aplica nonce ao <script> inline do tema e ao importmap" do
    get new_user_session_path
    # todo <script> inline (com conteúdo) precisa ter nonce sob a CSP
    inline_scripts = response.body.scan(/<script(?![^>]*\bsrc=)[^>]*>/)
    expect(inline_scripts).to be_present
    inline_scripts.each do |tag|
      expect(tag).to include("nonce="), "script inline sem nonce: #{tag}"
    end
  end

  it "os gráficos (Chartkick) recebem nonce no dashboard" do
    sign_in create(:user, :admin)
    get root_path
    expect(response).to have_http_status(:ok)

    chart_scripts = response.body.scan(/<script(?![^>]*\bsrc=)[^>]*>/)
    expect(chart_scripts).to be_present
    chart_scripts.each do |tag|
      expect(tag).to include("nonce="), "script inline sem nonce no dashboard: #{tag}"
    end
  end
end
