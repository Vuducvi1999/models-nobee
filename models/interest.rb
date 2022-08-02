class Interest < ApplicationRecord
  belongs_to :user
  #validate :check_interest

  def no_interest_exists
    attributes.all? do |k, v|
      ['id', 'user_id', 'created_at', 'updated_at'].include?(k) || v.nil? || v == [] || v == [""] || v == "0" || !v
    end
  end


  def check_interest
    if no_interest_exists
      self.errors.add(:base, "Select at least one interest")
    end
  end


end
