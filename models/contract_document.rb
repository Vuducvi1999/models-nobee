class ContractDocument < ApplicationRecord
  belongs_to :contract
  belongs_to :user
  has_one_attached :document

end
