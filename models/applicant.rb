class Applicant < ApplicationRecord
  validates :email, presence: true, format: { with: /\A([\w+\-]\.?)+@[a-z\d\-]+(\.[a-z]+)*\.[a-z]+\z/i }
  validates :first_name, presence: true
  validates :last_name, presence: true
  validates :phone, presence: true
  validates :home, presence: true
  validates_uniqueness_of :email, scope: :home_id

  belongs_to :home
end
