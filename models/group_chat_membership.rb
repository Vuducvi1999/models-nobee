class GroupChatMembership < ApplicationRecord
  belongs_to :group_chat
  belongs_to :user
  validates :user, uniqueness: { scope: :group_chat }
end
