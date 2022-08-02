class ContractInvitation < ApplicationRecord
  belongs_to :contract
  belongs_to :home
  belongs_to :user
end
