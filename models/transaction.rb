class Transaction < ApplicationRecord
  belongs_to :submitted_property_application, optional: true
  belongs_to :contract, optional: true
  belongs_to :user
  belongs_to :home
end
