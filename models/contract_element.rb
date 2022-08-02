class ContractElement < ApplicationRecord
  belongs_to :contract
  attr_accessor :x, :y, :w, :h
  before_save :add_dimensions



  def add_dimensions
    if (x && y)
      self.position_size = {x: x, y: y, w: w, h: h}
    end
  end
end
