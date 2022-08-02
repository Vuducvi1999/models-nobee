class AppleRefreshToken < ApplicationRecord
  belongs_to :user, optional: true
end
