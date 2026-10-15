class AddFieldsToUsersAndDropProfileKind < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :role, :integer, default: 0, null: false
    add_column :users, :full_name, :string
    add_column :users, :cpf, :string
    add_index :users, :cpf, unique: true

    remove_column :driver_profiles, :kind, :integer, default: 0, null: false
  end
end
