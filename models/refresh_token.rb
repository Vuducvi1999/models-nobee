class RefreshToken < ApplicationRecord
  belongs_to :user
  belongs_to :expo_token, optional: true
end
