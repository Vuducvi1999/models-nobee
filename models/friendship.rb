class Friendship < ApplicationRecord
  belongs_to :user, touch: true
  belongs_to :friend, class_name: "User"

  validates :user_id, presence: true, uniqueness: { scope: :friend_id }
  validates :friend_id, presence: true

  # bidirectional friendship
  after_create do |p|
    if !Friendship.where(user_id: p.friend_id, friend_id: p.user_id).exists?
      Friendship.create!(user_id: p.friend_id, friend_id: p.user_id)
    end
  end

  after_destroy do |p|
    reciprocal = Friendship.find_by(user_id: p.friend_id, friend_id: p.user_id)
    reciprocal.destroy unless reciprocal.nil?
  end

  def other(current_user)
    current_user == user ? friend : user
  end
end
