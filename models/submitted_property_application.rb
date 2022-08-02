class SubmittedPropertyApplication < ApplicationRecord
  belongs_to :group
  #validates :user, uniqueness: { scope: :group_chat }
  belongs_to :home, touch: true
  belongs_to :user
  has_many :transactions
  has_many :custom_app_documents
  has_many :application_documents
  has_one_attached :filled_application
  has_one_attached :credit_report
  has_one_attached :criminal_report
  has_one_attached :eviction_report

  def send_review(decision)
    # send email and in app notification
    if decision == "approved"
      ApplicationsMailer.send_application_decision_approved(self).deliver_now
    elsif decision == "rejected"
      # ApplicationsMailer.send_application_decision_rejected(self).deliver_now
    end
  end
end
