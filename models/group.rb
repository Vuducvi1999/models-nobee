class Group < ApplicationRecord
  belongs_to :user, optional: true
  belongs_to :home, touch: true
  belongs_to :contract, optional: true
  has_many :group_memberships, dependent: :destroy
  has_many :members, through: :group_memberships, source: :user
  has_many :group_invites, dependent: :destroy
  has_many :applications, through: :submitted_property_applications
  has_many :submitted_property_applications
  has_many :join_requests, dependent: :destroy
  has_many :requesters, through: :join_requests, source: :requester

  validates :name, presence: true
  validate :user_with_group_cannot_create, :on => :create
  validate :landlord_cannot_create_a_group

  def user_with_group_cannot_create
    return true if user_id.nil?

    user = User.find(user_id)

    if publicly_visible == true && user.groups.where(home_id: home_id).any?
      errors[:base] << "You cannot be in more than one group for a property"
    end
  end

  def landlord_cannot_create_a_group
    return true if user.nil?
    if user == home.user
      errors.add(:user, "cannot be landlord of this home")
    end
  end
end
