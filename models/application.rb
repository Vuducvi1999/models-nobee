class Application < ApplicationRecord
  belongs_to :user
  #belongs_to :group, optional: true
  has_many :groups, through: :submitted_property_applications
  has_many :submitted_property_applications
  encrypts :ssn

  #validates :ssn, numericality: true, :if => :last_step?
  validates :full_name, presence: true, :if => :last_step?
  #validates :initial, presence: true, :if => :last_step?
  #validates :phone_number, presence: true, :if => :last_step?
  #validates :country_code, presence: true, :if => :last_step?
  #validates :email, presence: true, :if => :last_step?
  #validates :address, presence: true, :if => :last_step?
  #validates :city, presence: true, :if => :last_step?
  #validates :state, presence: true, :if => :last_step?

  #validates :has_landlord, inclusion: { in: [ true, false ] }, :if => :last_step?
  #validates :present_landlord_name, presence: true, :if => :last_step_and_has_landlord?
  #validates :present_landlord_phone_number, presence: true, :if => :last_step_and_has_landlord?
  #validates :present_landlord_email, presence: true, :if => :last_step_and_has_landlord?

  #validates :had_landlord, inclusion: { in: [ true, false ] }, :if => :last_step?
  #validates :former_landlord_name, presence: true, :if => :last_step_and_had_landlord?
  #validates :former_landlord_phone_number, presence: true, :if => :last_step_and_had_landlord?
  #validates :former_landlord_email, presence: true, :if => :last_step_and_had_landlord?

  #validates :is_employed, inclusion: { in: [ true, false ] }, :if => :last_step?
  #validates :employer_name, presence: true, :if => :last_step_and_is_employed?
  #validates :employer_phone_number, presence: true, :if => :last_step_and_is_employed?
  #validates :employer_address, presence: true, :if => :last_step_and_is_employed?
  #validates :employer_city, presence: true, :if => :last_step_and_is_employed?
  #validates :employer_state, presence: true, :if => :last_step_and_is_employed?
  #validates :job_position, presence: true, :if => :last_step_and_is_employed?
  #validates :position_type, presence: true, :if => :last_step_and_is_employed?
  #validates :salary, presence: true, :if => :last_step_and_is_employed?
  #validates :employment_start, presence: true, :if => :last_step_and_is_employed?
  #validates :employment_end, presence: true, :if => :last_step_and_is_employed?

  #validates :was_employed, inclusion: { in: [ true, false ] }, :if => :last_step?
  #validates :former_employer_name, presence: true, :if => :last_step_and_was_employed?
  #validates :former_employer_phone_number, presence: true, :if => :last_step_and_was_employed?
  #validates :former_employer_address, presence: true, :if => :last_step_and_was_employed?
  #validates :former_employer_city, presence: true, :if => :last_step_and_was_employed?
  #validates :former_employer_state, presence: true, :if => :last_step_and_was_employed?
  #validates :former_job_position, presence: true, :if => :last_step_and_was_employed?
  #validates :former_position_type, presence: true, :if => :last_step_and_was_employed?
  #validates :former_salary, presence: true, :if => :last_step_and_was_employed?
  #validates :former_employment_start, presence: true, :if => :last_step_and_was_employed?
  #validates :former_employment_end, presence: true, :if => :last_step_and_was_employed?

  #validates :checking_bank_name, presence: true, :if => :last_step?
  #validates :checking_routing_number, presence: true, :if => :last_step?
  #validates :checking_account_number, presence: true, :if => :last_step?
  #validates :has_savings, inclusion: { in: [ true, false ] }, :if => :last_step?
  #validates :savings_routing_number, presence: true, :if => :last_step_and_has_savings?
  #validates :savings_account_number, presence: true, :if => :last_step_and_has_savings?

  #validates :zip, presence: true, :if => :last_step?
  #validates :date_of_birth, presence: true, :if => :last_step?


  private

  def last_step?
    last_step == true
  end

  def last_step_and_is_employed?

    last_step? && is_employed == true

  end

  def last_step_and_was_employed?

    last_step? && was_employed == true

  end

  def last_step_and_has_landlord?

    last_step? && has_landlord == true

  end

  def last_step_and_had_landlord?

    last_step? && had_landlord == true

  end

  def last_step_and_has_savings?

    last_step? && has_savings == true

  end


end
