class Activity < ApplicationRecord
  belongs_to :activitable, polymorphic: true, optional: true
  belongs_to :user
end
