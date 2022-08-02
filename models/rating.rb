class Rating < ApplicationRecord
  belongs_to :reviewer, :class_name => "User"
  belongs_to :local_guide, optional: true
  belongs_to :user, optional: true
  belongs_to :home, optional: true
end
