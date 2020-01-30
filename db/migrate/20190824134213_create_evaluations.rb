class CreateEvaluations < ActiveRecord::Migration[5.2]
  def change
    create_table :evaluations do |t|
      t.string :date
      t.string :hospital
      t.string :entity
      t.string :address
      t.integer :wait_vote
      t.integer :struct_vote
      t.integer :service_vote
      t.string :firebase_id
      t.string :firebase_id_public

      t.timestamps
    end
  end
end
