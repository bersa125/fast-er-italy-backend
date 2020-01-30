class CreateAddresses < ActiveRecord::Migration[5.2]
  def change
    create_table :addresses do |t|
      t.string :address
      t.decimal :latitude
      t.decimal :longitude
      t.string :entity_id
      t.string :entity_type
      t.string :firebase_id

      t.timestamps
    end
  end
end
