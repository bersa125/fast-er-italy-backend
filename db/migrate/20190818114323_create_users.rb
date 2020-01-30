class CreateUsers < ActiveRecord::Migration[5.2]
  def change
    create_table :users, :id => false do |t|
      t.string :id
      
      t.timestamps
    end
  end
end
