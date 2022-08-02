class EventAttendance < ApplicationRecord
  has_paper_trail on: [:create, :destroy, :update]
  include UsersHelper
  belongs_to :user
  belongs_to :calendar_event, touch: true
  after_commit :update_lead_status
  after_commit :mark_showing_as_cancelled
  after_commit :mark_showing_as_confirmed
  after_create :change_scheduled_event_attendances
  validates_uniqueness_of :user_id, :scope => :calendar_event_id

  after_commit :track_user_activity
  after_destroy do
    calendar_event = self.calendar_event
    if calendar_event.event_attendances.empty?
      calendar_event.update(event_type: "cancelled")
    end
  end

  def track_user_activity
    title = ""
    content = ""
    case status
    when "requested"
      title = "Showing request: #{calendar_event.home.full_address}"
      content = "#{calendar_event.home.full_address}, request #{calendar_event.start_datetime.in_time_zone('Eastern Time (US & Canada)')}"
    when "confirmed"
      title = "Showing Attendance Confirmed: #{calendar_event.home.full_address}"
      content = "#{calendar_event.home.full_address}, #{calendar_event.start_datetime.in_time_zone('Eastern Time (US & Canada)')}, #{user.full_name} confirmed"
    when "attended"
      title = "Showing Attendance Attended: #{calendar_event.home.full_address}"
      content = "#{calendar_event.home.full_address}, #{calendar_event.start_datetime.in_time_zone('Eastern Time (US & Canada)')}, #{user.full_name} attended"
    when "cancelled"
      if ENV["CLIENT_CANCELLATION_REASONS"].include? cancel_reason
        title = "Showing Cancelled: #{calendar_event.home.full_address}"
        content = "#{calendar_event.home.full_address}, #{calendar_event.start_datetime.in_time_zone('Eastern Time (US & Canada)')}, #{user.full_name} cancelled with reason: #{cancel_reason}"
      end
    end

    if title.present? && content.present?
      user.activities.create(
        title: title,
        content: content,
        activitable_id: calendar_event_id,
        activitable_type: "CalendarEvent"
      )
    end
  end

  def update_lead_status
    lead_status = ""
    if status == "requested"
      home = calendar_event.home
      lead_status = "Scheduled Showing #{home.state == "NY" ? "New York" : "Boston"}"
    elsif status == "cancelled" && self.calendar_event.scheduled_at
      lead_status = "Cancelled/No Show"
    elsif status == "waiting"
      lead_status = "Admin Confirmed Showing"
    elsif status == "confirmed"
      lead_status = "Client Confirmed Showing"
    end
    if lead_status != ""
      change_contact_lead_status(user.email, lead_status)
    end
  end

  def mark_showing_as_cancelled
    # if all attendees of showing have statuses are "cancelled". Also mark showing as cancelled

    if saved_change_to_status? && status == "cancelled"
      calendar_event = self.calendar_event
      if calendar_event.event_attendances.pluck(:status).uniq == ["cancelled"]
        calendar_event.update(event_type: "cancelled", cancel_reason: cancel_reason)
        if self.calendar_event.scheduled_at
          if ENV["CLIENT_CANCELLATION_REASONS"].split(", ").include? (cancel_reason)
            NotificationSender.new("client cancelled", calendar_event.id).send
          elsif ENV["ADMIN_CANCELLATION_REASONS"].split(", ").include? (cancel_reason)
            NotificationSender.new("admin cancelled", calendar_event.id).send
          elsif cancel_reason == ENV["SYSTEM_CANCELLATION_REASON"]
            NotificationSender.new("system cancelled", calendar_event.id).send
          elsif ENV["AGENT_CANCELLATION_REASONS"].split(", ").include? (cancel_reason)
            NotificationSender.new("agent cancelled", calendar_event.id).send
          elsif cancel_reason == "tenant cancelled"
            NotificationSender.new("tenant cancelled", calendar_event.id).send
          elsif cancel_reason == "unit rented"
            NotificationSender.new("unit rented", calendar_event.id).send
          elsif calendar_event.scheduled_at
            NotificationSender.new("client cancelled", calendar_event.id).send
          end
        end

        #Send mail to agent and tenants
      end
      TimedTask.where(showing_id: calendar_event.id, client_id: user_id).update_all(completed: true)
      if ENV["CLIENT_CANCELLATION_REASONS"].split(", ").include? (cancel_reason)
          TimedTask.create(title: "Call up a client, find out why they cancelled, ask them to reschedule", deadline: Time.now + 30.minutes, showing_id: calendar_event.id, client_id: user_id, department: 'blt')
      end
    end
  end

  def mark_showing_as_confirmed
    # if one of attendees of showing have statuses are "confirmed". Also mark showing as showing

    if saved_change_to_status? && status == "confirmed"
      self.calendar_event.update(event_type: "showing")
      NotificationSender.new("confirm push notification", self.id).send
    end
  end

  def change_scheduled_event_attendances
    calendar_event = self.calendar_event
    if calendar_event.scheduled_at
      self.update(target: user.email,
      showing_code: calendar_event.showing_code,
      status: 'waiting')
    end
  end


end
