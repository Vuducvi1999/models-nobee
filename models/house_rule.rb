class HouseRule < ApplicationRecord
  #belongs_to :home
  validates :description, presence:true
end
