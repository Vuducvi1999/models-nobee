class JoinRequest < ApplicationRecord
  belongs_to :group
  belongs_to :requester, class_name: "User"
end
