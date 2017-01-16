class CreateLineItemActions < ActiveRecord::Migration[4.2]
  def change
    create_table :spree_line_item_actions do |t|
      t.references :line_item, index: true, null: false
      t.references :action, index: true, null: false
      t.integer :quantity, default: 0
      t.timestamps null: true
    end
  end
end
