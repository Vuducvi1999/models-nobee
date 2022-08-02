class ShowingInvite < ApplicationRecord

  belongs_to :calendar_event
  belongs_to :user, optional: true
  belongs_to :inviter, class_name: "User"
  has_many :notifications, as: :notifiable


end
