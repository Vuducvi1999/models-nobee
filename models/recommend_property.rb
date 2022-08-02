class RecommendProperty < ApplicationRecord
  validates :home, uniqueness: { scope: :user }

  belongs_to :user
  belongs_to :home
end
