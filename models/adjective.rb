class Adjective < ApplicationRecord
  belongs_to :user
  #validate :check_adjective



  def no_adjective_exists
    attributes.all? do |key, val|
      ['id', 'user_id', 'created_at', 'updated_at'].include?(key) || val.nil? || val== [] || val == [""] || val == "0" || !val
    end
  end



  def check_adjective
    if no_adjective_exists
      self.errors.add(:base, "Select at least one word to describe yourself")
    end
  end
end
