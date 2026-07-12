require "digest"

# Orquestra a importação de um documento de resultados:
# SHA-256 → deduplicação → Active Storage → extração → parseamento →
# reconhecimento do piloto → fica aguardando revisão manual.
class ResultImportService
  FILENAME_DATE_RE = /\A(\d{2})(\d{2})(\d{4})[ _-]?(\d{2})(\d{2})?/

  Result = Struct.new(:document, :duplicate, keyword_init: true) do
    def duplicate? = duplicate
  end

  def self.call(path: nil, io: nil, filename:, content_type:, batch: nil, suggested_profile: nil)
    new.call(path:, io:, filename:, content_type:, batch:, suggested_profile:)
  end

  def call(path:, io:, filename:, content_type:, batch:, suggested_profile:)
    data = path ? File.binread(path) : io.read
    sha = Digest::SHA256.hexdigest(data)

    if (existing = SourceDocument.find_by(sha256: sha))
      return Result.new(document: existing, duplicate: true)
    end

    doc = SourceDocument.create!(
      import_batch: batch,
      filename: filename,
      sha256: sha,
      content_type: content_type,
      byte_size: data.bytesize,
      status: "pending",
      suggested_session_date: suggested_date_from(filename)
    )
    doc.file.attach(io: StringIO.new(data), filename:, content_type:)

    process(doc, data, content_type, suggested_profile)
    Result.new(document: doc, duplicate: false)
  end

  private

  def process(doc, data, content_type, suggested_profile)
    Tempfile.create([ "import", File.extname(doc.filename) ], binmode: true) do |tmp|
      tmp.write(data)
      tmp.flush

      extraction = DocumentTextExtractor.call(tmp.path, content_type: content_type)
      parsed = KgvResultParser.call(extraction.text, band_lines: extraction.band_lines || [])

      rows = parsed[:rows].map do |row|
        driver = DriverMatcher.match(row[:name])
        row.merge(matched_driver_id: driver&.id)
      end

      doc.update!(
        status: "parsed",
        raw_text: extraction.text,
        pages: extraction.pages,
        confidence: combined_confidence(extraction.confidence, parsed[:row_confidence]),
        parser_name: parsed[:parser_name],
        parser_version: parsed[:parser_version],
        parsed_data: parsed.except(:rows).merge(
          rows: rows,
          extraction_method: extraction.method,
          suggested_profile: suggested_profile
        )
      )
    end
  rescue => e
    doc.update!(status: "failed", error_message: e.message)
    raise if Rails.env.test?
  end

  def combined_confidence(ocr_conf, row_conf)
    [ ocr_conf, row_conf ].compact.sum / 2.0
  end

  def suggested_date_from(filename)
    m = FILENAME_DATE_RE.match(File.basename(filename, ".*"))
    return nil unless m
    day, month, year, hour, minute = m.captures
    Time.zone.local(year.to_i, month.to_i, day.to_i, hour.to_i, minute.to_i)
  rescue ArgumentError
    nil
  end
end
