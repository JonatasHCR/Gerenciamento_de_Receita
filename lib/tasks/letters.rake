# Converte modelos antigos (marcadores AAA…LLL) para os marcadores {{...}} e salva
# em modelos/. Uso:
#   SRC=tmp/z_src DEST=modelos bin/rails letters:convert_models
namespace :letters do
  desc "Converte modelos .doc/.docx (AAA…LLL → {{...}}) de SRC para DEST"
  task convert_models: :environment do
    src  = ENV.fetch("SRC", "tmp/z_src")
    dest = ENV.fetch("DEST", "modelos")
    FileUtils.mkdir_p(dest)

    arquivos = Dir.glob(File.join(src, "*.{doc,docx}"))
    if arquivos.empty?
      puts "Nenhum modelo em #{src}."
      next
    end

    arquivos.sort.each do |path|
      bytes = File.binread(path)
      unless bytes.byteslice(0, 2) == "PK"
        puts "PULADO (não é OOXML/zip): #{File.basename(path)}"
        next
      end
      convertido = Letters::TokenConverter.new(bytes).call
      out_name = "#{File.basename(path, '.*')}.docx"
      File.binwrite(File.join(dest, out_name), convertido)
      puts "OK: #{File.basename(path)} → #{dest}/#{out_name}"
    end
    puts "Concluído: #{arquivos.size} modelo(s) em #{dest}/."
  end
end
