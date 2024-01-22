class AddSpouseToUsers < ActiveRecord::Migration[6.1]
  def change
    add_column :users, :spouse_name, :string
    add_column :users, :spouse_email, :string
    add_column :users, :spouse_ssn, :integer
  end
end
