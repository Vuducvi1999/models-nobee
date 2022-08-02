class GroupInvite < ApplicationRecord
  include ApplicationHelper
  #include RenderSync::Actions

  validates :group_id, presence: true
  validates :suggester_id, presence: true
  #validate :suggester_and_receiver_are_friends
  #validate :user_follow_home
  validate :cannot_invite_landlord

  belongs_to :group
  belongs_to :user, optional: true
  belongs_to :suggester, class_name: "User"
  has_many :notifications, as: :notifiable, dependent: :nullify
  has_many :approvals, dependent: :destroy
  has_many :approving_users, through: :approvals, source: :user

  scope :approved, -> { where(approved: true) }

  before_destroy :touch_notifications

  def suggester_and_receiver_are_friends
    user = User.find(user_id)
    suggester = User.find(suggester_id)

    unless suggester.friends.include?(user)
      errors.add(:user, "must be friends with the suggester")
    end
  end

  def touch_notifications
    notifications.update_all(updated_at: Time.now)
  end

  def user_follow_home
    user = User.find(user_id)
    home = Group.find(group_id).home

    unless user.followed_homes.include?(home)
      errors.add(:user, "must follow homes first")
    end
  end

  def cannot_invite_landlord
    if user == group.home.user
      errors.add(:user, "cannot be the home's landlord")
    end
  end

  # check if group invite has enough approvals
  def approved?
    self.group.members.count == self.approvals.count
  end

  # send invites and change status to approved
  def send_invite
    # # send email and in app notification
    GroupInviteMailer.send_invitation(self.group, self.user).deliver_now

    self.update(approved: true)
  end
end
