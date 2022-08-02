class Owner < ApplicationRecord
  has_paper_trail on: [:create, :destroy, :update]
  has_many :homes

end
