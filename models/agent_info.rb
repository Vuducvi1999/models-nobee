class AgentInfo < ApplicationRecord
  belongs_to :user
  has_many :showing_payments
  has_one_attached :license_photo
end
