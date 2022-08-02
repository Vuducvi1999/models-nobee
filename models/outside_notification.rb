class OutsideNotification < ApplicationRecord
  include SessionsHelper
  belongs_to :notifiable, polymorphic: true

  after_commit :track_user_activity

  def track_user_activity
    user = User.where("email = ? OR phone LIKE ?", self.recipient, "%#{self.recipient}%").last

    return if user.blank?

    user.activities.create(
      title: "Notified to #{user.full_name}",
      content: self.message,
      activitable_id: self.id,
      activitable_type: "OutsideNotification"
    )
  end
end
