class Contract < ApplicationRecord
  belongs_to :home
  has_many :contract_signatures
  has_one_attached :contract_form
  has_many_attached :images
  has_many :contract_documents
  has_one :group
  has_many :contract_elements, :dependent => :destroy
  has_many :invited_users, through: :contract_invitations, source: :user
  has_many :contract_invitations, :dependent => :destroy
  has_many :transactions


end
