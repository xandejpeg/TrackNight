require "open3"
require "csv"
require "tmpdir"

# OCR local de imagens de resultados usando ImageMagick (pré-processamento)
# e Tesseract (saída TSV com confiança por palavra).
#
# Estratégia em duas passadas:
#   1. Página inteira — remove marcações vermelhas reconstruindo os glifos
#      (pixels vermelhos recebem o vizinho vertical não-vermelho mais próximo),
#      inverte células roxas (melhor setor da sessão) e aplica OCR.
#   2. Faixa destacada — se existir um retângulo vermelho desenhado sobre uma
#      linha, recorta essa faixa e aplica OCR em múltiplas variantes de escala
#      e binarização. As leituras alternativas ("band_lines") alimentam a
#      fusão por votação no KgvResultParser.
class ImageOcrExtractor
  Result = Struct.new(:text, :confidence, :band_lines, keyword_init: true)

  # Pixels vermelhos herdam o primeiro vizinho vertical não-vermelho (acima ou
  # abaixo, o mais escuro), reconstruindo topos/bases de glifos cortados pela
  # marcação. Onde não há vizinho útil, vira branco.
  RED_RECONSTRUCT_FX =
    "(u.r-max(u.g,u.b)>0.16 && u.r>0.45) ? min( " \
    "(p[0,1].r-max(p[0,1].g,p[0,1].b)>0.16 && p[0,1].r>0.45) ? ((p[0,2].r-max(p[0,2].g,p[0,2].b)>0.16 && p[0,2].r>0.45) ? 1 : p[0,2]) : p[0,1], " \
    "(p[0,-1].r-max(p[0,-1].g,p[0,-1].b)>0.16 && p[0,-1].r>0.45) ? ((p[0,-2].r-max(p[0,-2].g,p[0,-2].b)>0.16 && p[0,-2].r>0.45) ? 1 : p[0,-2]) : p[0,-1] " \
    ") : u"

  PURPLE_MASK_FX = "(u.b - u.g > 0.15 && u.r - u.g > 0.12) ? 1 : 0"
  RED_BAND_FX = "(u.r - max(u.g,u.b) > 0.25) ? 1 : 0"
  RED_WHITEN_FX = "(u.r-max(u.g,u.b)>0.16 && u.r>0.45) ? 1.0 : u"

  BAND_VARIANTS = [
    [ "-filter", "Lanczos", "-resize", "250%" ],
    [ "-filter", "Lanczos", "-resize", "300%" ],
    [ "-filter", "Lanczos", "-resize", "400%" ],
    [ "-filter", "Lanczos", "-resize", "400%", "-level", "20%,80%" ],
    [ "-filter", "Lanczos", "-resize", "500%", "-level", "20%,80%" ],
    [ "-filter", "Lanczos", "-resize", "500%" ],
    [ "-filter", "Lanczos", "-resize", "600%", "-level", "25%,75%" ],
    [ "-filter", "Lanczos", "-resize", "300%", "-threshold", "55%" ]
  ].freeze

  def self.call(path) = new.call(path)

  def call(path)
    Dir.mktmpdir("ocr") do |dir|
      base_fx = build_clean_base(path, dir, RED_RECONSTRUCT_FX, "fx")
      base_plain = build_clean_base(path, dir, RED_WHITEN_FX, "plain")

      results = [ base_fx, base_plain ].map do |base|
        full = File.join(dir, "full_#{File.basename(base, '.png')}.png")
        magick!(base, "-resize", "300%", "-level", "25%,75%", "-sharpen", "0x1", full)
        build_result(run_tesseract_tsv(full))
      end
      result = results.max_by(&:confidence)
      result.band_lines = extract_band_lines(path, [ base_fx, base_plain ], dir)
      result
    end
  end

  private

  def magick_bin = ENV.fetch("IMAGEMAGICK_PATH", "magick")
  def tesseract_bin = ENV.fetch("TESSERACT_PATH", "tesseract")

  def magick!(*args)
    _, err, status = Open3.capture3(magick_bin, *args)
    raise "ImageMagick falhou: #{err}" unless status.success?
  end

  def magick_query(*args)
    out, err, status = Open3.capture3(magick_bin, *args)
    raise "ImageMagick falhou: #{err}" unless status.success?
    out.strip
  end

  # Base limpa na escala original: vermelho tratado + células roxas invertidas.
  def build_clean_base(path, dir, red_fx, tag)
    red_fixed = File.join(dir, "red_fixed_#{tag}.png")
    mask = File.join(dir, "purple_mask_#{tag}.png")
    gray = File.join(dir, "gray_#{tag}.png")
    neg = File.join(dir, "neg_#{tag}.png")
    base = File.join(dir, "base_#{tag}.png")

    magick!(path, "-fx", red_fx, red_fixed)
    magick!(red_fixed, "-fx", PURPLE_MASK_FX, "-colorspace", "Gray",
            "-morphology", "Close", "Disk:4", mask)
    # canal verde como "grayscale": o sangramento vermelho do JPEG some nele,
    # mantendo os glifos tingidos com contraste total
    magick!(red_fixed, "-channel", "G", "-separate", gray)
    magick!(gray, "-negate", neg)
    magick!(gray, neg, mask, "-composite", base)
    base
  end

  def run_tesseract_tsv(path)
    out, err, status = Open3.capture3(tesseract_bin, path, "stdout", "--psm", "6", "--dpi", "300", "-l", "eng", "tsv")
    raise "Tesseract falhou: #{err}" unless status.success?
    out
  end

  def run_tesseract_text(path, psm)
    out, _err, status = Open3.capture3(tesseract_bin, path, "stdout", "--psm", psm.to_s, "--dpi", "300", "-l", "eng")
    status.success? ? out : ""
  end

  # Localiza o retângulo vermelho (destaque manual) e OCR-iza a faixa em
  # múltiplas variantes, coletando leituras alternativas da linha destacada.
  # Três tiras diversificam as leituras para a fusão por votação; a do canal
  # vermelho é a mais fiel porque o traço vermelho some naturalmente nela.
  def extract_band_lines(original_path, _bases, dir)
    bbox = detect_red_band(original_path, dir)
    return [] unless bbox

    _w, h, _x, y = bbox
    strip = File.join(dir, "strip_color.png")
    magick!(original_path, "-crop", "99999x#{[ h - 4, 10 ].max}+0+#{y + 2}", "+repage", strip)

    strips = [
      build_red_strip(strip, dir),
      build_strip(strip, dir, "green", RED_WHITEN_FX, "Disk:4", :green),
      build_strip(strip, dir, "luma", "(u.r-max(u.g,u.b)>0.2) ? 1.0 : u", "Disk:6", :luma)
    ]

    lines = []
    strips.each_with_index do |base, bi|
      BAND_VARIANTS.each_with_index do |variant, i|
        out = File.join(dir, "band_#{bi}_v#{i}.png")
        magick!(base, *variant, "-bordercolor", "white", "-border", "25", out)
        [ 6, 7 ].each do |psm|
          run_tesseract_text(out, psm).each_line do |line|
            line = line.strip
            lines << line if band_row_line?(line)
          end
        end
      end
    end
    lines.uniq
  end

  # Tira via canal vermelho: tinta vermelha tem R≈1 (como o fundo branco),
  # então o destaque desaparece sem pós-processamento e os glifos ficam íntegros.
  def build_red_strip(strip_color, dir)
    mask = File.join(dir, "strip_mask_red.png")
    gray = File.join(dir, "strip_gray_red.png")
    neg = File.join(dir, "strip_neg_red.png")
    base = File.join(dir, "strip_base_red.png")

    magick!(strip_color, "-fx", PURPLE_MASK_FX, "-colorspace", "Gray", "-morphology", "Close", "Disk:4", mask)
    magick!(strip_color, "-channel", "R", "-separate", gray)
    magick!(gray, "-negate", neg)
    magick!(gray, neg, mask, "-composite", base)
    base
  end

  def build_strip(strip_color, dir, tag, whiten_fx, purple_close, gray_mode)
    clean = File.join(dir, "strip_clean_#{tag}.png")
    mask = File.join(dir, "strip_mask_#{tag}.png")
    gray = File.join(dir, "strip_gray_#{tag}.png")
    neg = File.join(dir, "strip_neg_#{tag}.png")
    base = File.join(dir, "strip_base_#{tag}.png")

    magick!(strip_color, "-fx", whiten_fx, clean)
    magick!(clean, "-fx", PURPLE_MASK_FX, "-colorspace", "Gray", "-morphology", "Close", purple_close, mask)
    if gray_mode == :green
      magick!(clean, "-channel", "G", "-separate", gray)
    else
      magick!(clean, "-colorspace", "Gray", gray)
    end
    magick!(gray, "-negate", neg)
    magick!(gray, neg, mask, "-composite", base)
    base
  end

  def band_row_line?(line)
    line.scan(/\d/).size >= 6 && line =~ /\d[.,]\d{3}/
  end

  # Retorna [w, h, x, y] do retângulo vermelho, ou nil se não houver.
  def detect_red_band(path, dir)
    mask = File.join(dir, "red_band_mask.png")
    magick!(path, "-fx", RED_BAND_FX, "-colorspace", "Gray", "-morphology", "Open", "Square:2", mask)
    bbox = magick_query(mask, "-format", "%@", "info:")
    m = bbox.match(/\A(\d+)x(\d+)\+(\d+)\+(\d+)\z/)
    return nil unless m
    w, h, x, y = m.captures.map(&:to_i)
    return nil unless w >= 200 && h.between?(6, 80)
    [ w, h, x, y ]
  rescue
    nil
  end

  def build_result(tsv)
    lines = Hash.new { |h, k| h[k] = [] }
    confidences = []

    tsv.each_line.drop(1).each do |row|
      cols = row.chomp.split("\t")
      next if cols.size < 12
      level, block, par, line = cols[0].to_i, cols[2].to_i, cols[3].to_i, cols[4].to_i
      next unless level == 5
      conf = cols[10].to_f
      word = cols[11].to_s.strip
      next if word.empty?
      confidences << conf if conf >= 0
      lines[[ block, par, line ]] << word
    end

    text = lines.keys.sort.map { |key| lines[key].join(" ") }.join("\n")
    avg = confidences.any? ? (confidences.sum / confidences.size).round(2) : 0.0
    Result.new(text:, confidence: avg, band_lines: [])
  end
end
