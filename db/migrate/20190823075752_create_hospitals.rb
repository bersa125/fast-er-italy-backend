class CreateHospitals < ActiveRecord::Migration[5.2]
  def change
    create_table :hospitals do |t|
      t.string :place_name
      t.string :address_name

      t.timestamps
    end
  end
end
