class ApplicationDocument < ApplicationRecord
  belongs_to :submitted_property_application
  #validate :check_adjective


end
