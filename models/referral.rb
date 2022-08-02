class Referral < ApplicationRecord
  has_paper_trail on: [:create, :destroy, :update]
  belongs_to :referring_user, class_name: "User"
  belongs_to :referred_user, class_name: "User"
end
