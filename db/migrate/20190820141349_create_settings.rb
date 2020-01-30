class CreateSettings < ActiveRecord::Migration[5.2]
  def change
    create_table :settings do |t|
      t.integer :results_shown
      t.boolean :tracking
      t.string :entity_id
      t.string :firebase_id

      t.timestamps
    end
  end
end
