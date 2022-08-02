class LocalGuide < ApplicationRecord
  belongs_to :user
  has_one_attached :id_photo, :dependent => :destroy
  has_many_attached :prior_experience
  has_many_attached :showing_video
  has_many :ratings
end
