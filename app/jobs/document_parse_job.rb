# Executa o OCR/parseamento de um documento fora do ciclo da requisição HTTP.
# O upload responde imediatamente e o resultado aparece na tela de importações.
class DocumentParseJob < ApplicationJob
  queue_as :default

  discard_on ActiveJob::DeserializationError

  def perform(document, suggested_profile = nil)
    return unless document.status == "pending"

    ResultImportService.process(document, suggested_profile: suggested_profile)
    finish_batch(document.import_batch)
  end

  private

  def finish_batch(batch)
    return if batch.nil? || batch.status == "finished"
    return if batch.source_documents.where(status: "pending").exists?

    batch.update!(status: "finished", finished_at: Time.current)
  end
end
