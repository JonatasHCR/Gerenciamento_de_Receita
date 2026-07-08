require "rails_helper"

RSpec.describe Letters::Extenso do
  {
    0        => "zero reais",
    1        => "um real",
    2        => "dois reais",
    0.5      => "cinquenta centavos",
    100      => "cem reais",
    101      => "cento e um reais",
    700_000  => "setecentos mil reais",
    1234.56  => "mil duzentos e trinta e quatro reais e cinquenta e seis centavos",
    1_000_000 => "um milhão reais"
  }.each do |valor, texto|
    it "converte #{valor} → \"#{texto}\"" do
      expect(described_class.real(valor)).to eq(texto)
    end
  end
end
