class RenterConfirmation < ApplicationRecord
  enum status: { waiting: 0, confirmed: 1, cancelled: 2, rescheduled: 3 }

  belongs_to :calendar_event, optional: true
  belongs_to :user, foreign_key: :target, primary_key: :email, optional: true

  after_save :remove_calling_task, if: :saved_change_to_status?

  private

  def remove_calling_task
    if status == "cancelled"
      event_attendance = EventAttendance.find_by(user_id: self.user.id, calendar_event_id: self.calendar_event_id)

      return if event_attendance.blank?

      calling_tasks = ShowingTask.where(taskable_type: "EventAttendance", taskable_id: event_attendance.id)

      return if calling_tasks.blank?

      calling_tasks.destroy_all
    end
  end
end
