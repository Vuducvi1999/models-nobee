class FriendRequest < ApplicationRecord
  belongs_to :sender, class_name: "User"
  belongs_to :receiver, class_name: "User"
  has_many :notifications, as: :notifiable, dependent: :nullify

  validates :sender_id, presence: true, uniqueness: { scope: :receiver_id }
  validates :receiver_id, presence: true
  validate :only_one_friend_request_between_pair
  validate :cannot_send_request_to_friends

  # check if the receiver has sent a friend request to sender
  def only_one_friend_request_between_pair
    if FriendRequest.where(sender_id: receiver_id, receiver_id: sender_id).exists?
      errors[:base] << "You have already received a friend request from this person"
    end
  end

  def cannot_send_request_to_friends
    if User.find(sender_id).friends.include?(User.find(receiver_id))
      errors[:base] << "You are already friends"
    end
  end

  def other_user(user)
    user == current_user ? sender : receiver
  end
end
