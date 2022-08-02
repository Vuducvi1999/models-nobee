class ExpoToken < ApplicationRecord
  belongs_to :user
  has_many :refresh_tokens
end
