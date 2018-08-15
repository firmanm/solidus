class AddSpreePriceAmountPrecision < ActiveRecord::Migration
  def change
    change_column :spree_prices, :amount,  :decimal, :precision => 13, :scale => 0
    change_column :spree_line_items, :price,  :decimal, :precision => 13, :scale => 0, :null => false
    change_column :spree_line_items, :cost_price,  :decimal, :precision => 13, :scale => 0
    change_column :spree_variants, :cost_price, :decimal, :precision => 13, :scale => 0
  end
end
