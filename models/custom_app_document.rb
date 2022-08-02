class CustomAppDocument < ApplicationRecord
  belongs_to :submitted_property_application
  has_one_attached :filled_application
end
