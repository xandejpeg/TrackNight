# Extrai texto de um documento (imagem ou PDF), escolhendo a estratégia:
# 1. Texto nativo do PDF (pdf-reader)
# 2. OCR de imagem (ImageOcrExtractor)
# 3. PDF digitalizado: converte páginas em imagem e aplica OCR
class DocumentTextExtractor
  Result = Struct.new(:text, :confidence, :method, :pages, :band_lines, keyword_init: true)

  IMAGE_TYPES = %w[image/png image/jpeg image/jpg image/webp].freeze

  def self.call(path, content_type:) = new.call(path, content_type:)

  def call(path, content_type:)
    if content_type == "application/pdf"
      extract_pdf(path)
    elsif IMAGE_TYPES.include?(content_type)
      ocr = ImageOcrExtractor.call(path)
      Result.new(text: ocr.text, confidence: ocr.confidence, method: "image_ocr", pages: 1, band_lines: ocr.band_lines)
    else
      raise ArgumentError, "Tipo de arquivo não suportado: #{content_type}"
    end
  end

  private

  def extract_pdf(path)
    require "pdf-reader"
    reader = PDF::Reader.new(path)
    text = reader.pages.map(&:text).join("\n")
    if text.strip.length > 50
      Result.new(text:, confidence: 100.0, method: "pdf_text", pages: reader.page_count, band_lines: [])
    else
      ocr_scanned_pdf(path, reader.page_count)
    end
  rescue PDF::Reader::MalformedPDFError => e
    raise "PDF inválido: #{e.message}"
  end

  def ocr_scanned_pdf(path, page_count)
    require "open3"
    texts = []
    confs = []
    magick = ENV.fetch("IMAGEMAGICK_PATH", "magick")
    Dir.mktmpdir do |dir|
      out_pattern = File.join(dir, "page.png")
      _, err, status = Open3.capture3(magick, "-density", "300", path, out_pattern)
      unless status.success?
        raise "Não foi possível converter o PDF digitalizado em imagens (Ghostscript necessário): #{err}"
      end
      Dir[File.join(dir, "page*.png")].sort.each do |page_path|
        ocr = ImageOcrExtractor.call(page_path)
        texts << ocr.text
        confs << ocr.confidence
      end
    end
    avg = confs.any? ? (confs.sum / confs.size).round(2) : 0.0
    Result.new(text: texts.join("\n"), confidence: avg, method: "pdf_scanned_ocr", pages: page_count, band_lines: [])
  end
end
