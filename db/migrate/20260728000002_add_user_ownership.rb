class AddUserOwnership < ActiveRecord::Migration[8.1]
  def up
    add_reference :drivers, :user, foreign_key: true
    add_reference :race_sessions, :user, foreign_key: true
    add_reference :source_documents, :user, foreign_key: true
    add_reference :import_batches, :user, foreign_key: true

    # Backfill: tudo que existe hoje pertence ao primeiro usuário member
    # (dono histórico dos dados). Em dev/produção atuais: xandao.
    owner = User.where(role: :member).order(:id).first || User.order(:id).first
    if owner
      say_with_time "Backfilling ownership para user ##{owner.id} (#{owner.username})" do
        Driver.where(user_id: nil).update_all(user_id: owner.id)
        RaceSession.where(user_id: nil).update_all(user_id: owner.id)
        SourceDocument.where(user_id: nil).update_all(user_id: owner.id)
        ImportBatch.where(user_id: nil).update_all(user_id: owner.id)
      end
    end
  end

  def down
    remove_reference :import_batches, :user, foreign_key: true
    remove_reference :source_documents, :user, foreign_key: true
    remove_reference :race_sessions, :user, foreign_key: true
    remove_reference :drivers, :user, foreign_key: true
  end
end
