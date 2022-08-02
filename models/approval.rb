class Approval < ApplicationRecord
  validates :user_id, presence: true
  validates :group_invite_id, presence: true, uniqueness: { scope: :user_id }
  belongs_to :user
  belongs_to :group_invite
end
