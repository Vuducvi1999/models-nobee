class CalendarEvent < ApplicationRecord
  BLANK_IMAGE_URL = "http://i.stack.imgur.com/y9DpT.jpg"
  has_paper_trail on: [:create, :destroy, :update]
  belongs_to :user
  belongs_to :home, optional: true, touch: true
  belongs_to :room, optional: true
  belongs_to :agent, optional: true, foreign_key: :agent_id, class_name: 'User'
  has_many :event_attendances, dependent: :destroy
  has_many :outside_notifications, as: :notifiable
  has_many :attendees, through: :event_attendances, source: :user
  has_many :renter_confirmations
  has_many :tenant_confirmations
  has_many :showing_tasks, dependent: :destroy
  has_one :missing_info_checklist, dependent: :destroy
  after_commit -> { MissingInfoChecklist.create!(calendar_event: self) }, on: :create, if: -> { self.scheduled_at.blank? }
  after_commit :tracking_showing_status, on: [:create, :update]

  def is_pending_showing_request
    if self.event_type == "showing" && !self.start_datetime && !self.end_datetime
      return true
    else
      return false
    end
  end

  def is_scheduled_showing
    if self.event_type == "showing" &&
       ((home.current_tenant_emails.present? && home.current_tenant_emails.length > 4) ||
       TenantConfirmation.where(calendar_event_id: self.id,
                                status: "confirmed").last.present?)
      return true
    else
      return false
    end
  end

  def send_showing_reminder
    if event_type == "showing" && start_datetime.present?
      # Send first notification ( doesn't require option to respond )
      RenterReminderJob.perform_now(id: self.id, showing_code: self.showing_code, type: 'notify')
      # Send second notification ( require option to respond )
      RenterReminderJob.set(wait_until: start_datetime - 24.hours)
                       .perform_later(id: self.id, showing_code: self.showing_code, type: 'notify_within_respond_option')
      # Send third notification as reminder ( require option to respond )
      RenterReminderJob.set(wait_until: start_datetime - 4.hours)
                       .perform_later(id: self.id, showing_code: self.showing_code, type: 'remind')
      # Automatically mark showing as cancelled and send notification
      if start_datetime - Time.now > 2.hours
        RenterReminderJob.set(wait_until: start_datetime - 2.hours)
                         .perform_later(id: self.id, showing_code: self.showing_code, type: 'cancel')
      end

      AfterShowingJob.set(wait_until: start_datetime + 2.hours).perform_later(id: self.id, showing_code: self.showing_code )

      AfterShowingReminderJob.set(wait_until: start_datetime + 26.hours).perform_later(id: self.id, showing_code: self.showing_code )
      AfterShowingReminderJob.set(wait_until: start_datetime + 50.hours).perform_later(id: self.id, showing_code: self.showing_code )
    end
  end

  def send_cancel_notification_to_agents
    agents_phone = ENV["AGENT_NUMBERS"]&.split(", ") || []

    # Send text to agents only
    @full_address = self.home.address
    if self.home.apartment_number.present?
      address_split = self.home.address.split(/,(.+)/)
      @full_address = "#{address_split[0]}, Apt #{self.home.apartment_number}, #{address_split[1]}"
    end

    showing_day = self.start_datetime.in_time_zone('Eastern Time (US & Canada)').day
    date_display = "on " + self.start_datetime.in_time_zone('Eastern Time (US & Canada)').to_date.to_s
    if showing_day == DateTime.now.day
      date_display = "today"
    end

    agents_phone.each do |phone|
      message_body = "Hi there, the showing #{date_display} at #{@full_address} from #{self.start_datetime.in_time_zone('Eastern Time (US & Canada)').strftime("%I:%M %p")} - #{(self.start_datetime + 30.minutes).in_time_zone('Eastern Time (US & Canada)').strftime("%I:%M %p")} EST has been cancelled by the agent. Please reach out to client to reschedule \n\n- Nobee"

      send_sms(phone, message_body)
    end
  end

  def send_cancel_notification_to_attendees(property_rented = false)
    client_phones = attendees.map { |user| user&.get_correct_phone }

    # Send text to agents only
    @full_address = self.home.address
    if self.home.apartment_number.present?
      address_split = self.home.address.split(/,(.+)/)
      @full_address = "#{address_split[0]}, Apt #{self.home.apartment_number}, #{address_split[1]}"
    end

    showing_day = self.start_datetime.in_time_zone('Eastern Time (US & Canada)').day
    date_display = "on " + self.start_datetime.in_time_zone('Eastern Time (US & Canada)').to_date.to_s
    if showing_day == DateTime.now.day
      date_display = "today"
    end


    client_phones.each do |phone|
      message_body = "Hi there, the showing #{date_display} at #{@full_address} from #{self.start_datetime.in_time_zone('Eastern Time (US & Canada)').strftime("%I:%M %p")} - #{(self.start_datetime + 30.minutes).in_time_zone('Eastern Time (US & Canada)').strftime("%I:%M %p")} EST has been cancelled by our system. #{property_rented ? "That property was just rented out. Let us know if you want to schedule showings for other properties!": "Call us at 617-362-4845 if you have any questions."} \n\n- Nobee"

      send_sms(phone, message_body)
    end
  end

  def send_cancel_notification(system = true)
    if event_type == "cancelled" && start_datetime.present?
      # Send notification to agents, tenants, landlord
      tenants = self.home.current_tenant_emails&.split(",")
      tenant_emails = tenants&.select { |tenant| tenant.include?("@") }
      tenant_phones = tenants&.select { |tenant| !tenant.include?("@") }

      # Detect agents email and phone
      agents_email = []
      agents_phone = ENV["AGENT_NUMBERS"]&.split(", ") || []
      if agent&.phone.present? # if showing was assigned to agent
        phone_prefix = agent.country_code || "+1"
        agents_email = [agent.email]
        agents_phone << agent&.get_correct_phone
      end

      landlord_email = self.home&.landlord&.email
      landlord_phone = self.home&.landlord&.phone
      landlord_phone_prefix = self.home&.landlord&.country_code || "+1"
      landlord_phone = self.home&.landlord&.get_correct_phone

      # Send mail to landlord, agent
      all_emails_except_attendees = ([landlord_email] + agents_email).uniq.compact
      all_emails_except_attendees.each do |email|
        ShowingMailer.cancel_showing(self, email).deliver!
      end

      # Send text to landlord, agent
      @full_address = self.home.address
      if self.home.apartment_number.present?
        address_split = self.home.address.split(/,(.+)/)
        @full_address = "#{address_split[0]}, Apt #{self.home.apartment_number}, #{address_split[1]}"
      end

      showing_day = self.start_datetime.in_time_zone('Eastern Time (US & Canada)').day
      date_display = "on " + self.start_datetime.in_time_zone('Eastern Time (US & Canada)').to_date.to_s
      if showing_day == DateTime.now.day
        date_display = "today"
      end

      all_phones_except_attendees = ([landlord_phone] + agents_phone).uniq.compact
      all_phones_except_attendees.each do |phone|
        message_body = "Hi there, the showing #{date_display} at #{@full_address} from #{self.start_datetime.in_time_zone('Eastern Time (US & Canada)').strftime("%I:%M %p")} - #{(self.start_datetime + 30.minutes).in_time_zone('Eastern Time (US & Canada)').strftime("%I:%M %p")} EST has been cancelled by #{system ? "our system" : "the client"}. \n\n- Nobee"

        send_sms(phone, message_body)
      end
    end
  end

  def send_confirm_notification
    # renter
    if user.phone.present?
      msg_body = "Hi there! A showing of the property you requested (#{home.address}) is confirmed on #{start_datetime.in_time_zone('Eastern Time (US & Canada)').to_date.to_formatted_s(:long_ordinal)} at #{start_datetime.in_time_zone('Eastern Time (US & Canada)').strftime("%I:%M %p")} EST"

      send_sms(user.get_correct_phone, msg_body)

      OutsideNotification.create(notifiable_id: self.id, notifiable_type: "CalendarEvent", sender: 'Nobee',recipient: user.phone, message: msg_body, time_sent: Time.now)

    end

    # agents
    agent_numbers = ENV["AGENT_NUMBERS"]
    if agent_numbers.present?
      msg_body = "Hi there! A showing of your property (#{home.address}) is confirmed on #{start_datetime.in_time_zone('Eastern Time (US & Canada)').to_date.to_formatted_s(:long_ordinal)} at #{start_datetime.in_time_zone('Eastern Time (US & Canada)').strftime("%I:%M %p")} EST"

      agent_numbers.split(", ").each { |phone| send_sms(phone, msg_body) }
    end

    # landlord
    if home.landlord.phone.present? && home.landlord.country_code.present?
      msg_body = "Hi there! A showing of your property (#{home.address}) is confirmed on #{start_datetime.in_time_zone('Eastern Time (US & Canada)').to_date.to_formatted_s(:long_ordinal)} at #{start_datetime.in_time_zone('Eastern Time (US & Canada)').strftime("%I:%M %p")} EST"

      send_sms(home&.landlord&.get_correct_phone, msg_body)
    end

    # tenants
    if home.current_tenant_emails.present? && home.current_tenant_emails.length > 4
      home.current_tenant_emails.split(",").each do |tenant_info|
        is_email = tenant_info.include?("@")

        if is_email
          ShowingMailer.landlord_confirm_showing_time(
            self,
            User.new(email: tenant_info, first_name: "Tenant"),
            false
          ).deliver_now!
        else
          msg_body = "Hi there! A showing of the property you live in (#{home.address}) is confirmed on #{start_datetime.in_time_zone('Eastern Time (US & Canada)').to_date.to_formatted_s(:long_ordinal)} at #{start_datetime.in_time_zone('Eastern Time (US & Canada)').strftime("%I:%M %p")} EST"
          send_sms(tenant_info, msg_body)
        end
        OutsideNotification.create(notifiable_id: self.id, notifiable_type: "CalendarEvent", sender: 'Nobee', recipient: tenant_info, message: msg_body, time_sent: Time.now)
      end
    end
  end

  def send_reschedule_notification(exceptional_tenant: nil)
    # doesn't send mail or sms text to exceptional_tenant
    # renter

    @full_address = home.address

    if home.apartment_number.present?
      address_split = home.address.split(/,(.+)/)
      @full_address = "#{address_split[0]}, Apt #{home.apartment_number}, #{address_split[1]}"
    end

    @showing_date = self.start_datetime.to_date.to_formatted_s(:long_ordinal)
    @showing_start_time = self.start_datetime.in_time_zone('Eastern Time (US & Canada)').strftime("%I:%M %p")



    if user.phone.present?
      msg_body = "Hi there! #{home&.user&.full_name} of #{@full_address} notified you to reschedule the showing for their property on #{@showing_date} at #{@showing_start_time}"

      send_sms(user.get_correct_phone, msg_body)
      OutsideNotification.create(notifiable_id: self.id, notifiable_type: "CalendarEvent", sender: 'Nobee', recipient: user.phone, message: msg_body, time_sent: Time.now)
    end

    # agents
    agent_numbers = ENV["AGENT_NUMBERS"]
    if agent_numbers.present?
      msg_body = "Hi there! One of the tenants for #{home.address}, Apt. #{home.apartment_number} at #{Time.now} rejected a showing that #{user.name} requested.\nGo to https://www.rentnobee.com/dashboard/my-showings to respond"

      agent_numbers.split(", ").each { |phone| send_sms(phone, msg_body) }
    end

    # landlord
    if home.landlord.phone.present? && home.landlord.country_code.present?
      msg_body = "Hi there! One of the tenants for #{home.address} just rejected a showing.\nGo to https://www.rentnobee.com/dashboard/my-showings to respond"

      send_sms(home&.landlord&.get_correct_phone, msg_body)
    end

    # tenants
    if home.current_tenant_emails.present? && home.current_tenant_emails.length > 4
      home.current_tenant_emails.split(",").each do |tenant_info|
        next if exceptional_tenant.present? && exceptional_tenant == tenant_info

        is_email = tenant_info.include?("@")

        if is_email
          ShowingMailer.notify_to_tenant_reschedule_showing(home, tenant_info).deliver_now!
        else
          msg_body = "Hi there! One of the tenants for #{home.address} just rejected a showing.\nGo to https://www.rentnobee.com/dashboard/my-showings to respond"

          send_sms(tenant_info, msg_body)
        end
        OutsideNotification.create(notifiable_id: self.id, notifiable_type: "CalendarEvent", sender: 'Nobee', recipient: tenant_info, message: msg_body, time_sent: Time.now)
      end
    end
  end

  # Start Agents notification
  def send_confirm_notification_to_agents(confirmed_by_email = nil)
    internal_agent_phones = ENV["AGENT_NUMBERS"]&.split(", ") || []
    agent_phone = []
    if agent&.phone.present?
      phone_prefix = agent.country_code || "+1"
      agent_phone = [agent&.get_correct_phone]
    end

    all_phones = (internal_agent_phones + agent_phone).uniq.compact
    all_phones.each do |phone|
      msg_body = "Hi there! A showing of the property (#{home.full_address}) is confirmed #{confirmed_by_email ? "by #{confirmed_by_email} " : ""}on #{start_datetime.in_time_zone('Eastern Time (US & Canada)').to_date.to_formatted_s(:long_ordinal)} at #{start_datetime.in_time_zone('Eastern Time (US & Canada)').strftime("%I:%M %p")} EST"

      send_sms(phone, msg_body)
    end
  end

  def send_cancel_notification_to_agents
    internal_agent_phones = ENV["AGENT_NUMBERS"]&.split(", ") || []

    # Send text to agents only
    @full_address = self.home.address
    if self.home.apartment_number.present?
      address_split = self.home.address.split(/,(.+)/)
      @full_address = "#{address_split[0]}, Apt #{self.home.apartment_number}, #{address_split[1]}"
    end

    showing_day = self.start_datetime.in_time_zone('Eastern Time (US & Canada)').day
    date_display = "on " + self.start_datetime.in_time_zone('Eastern Time (US & Canada)').to_date.to_s
    if showing_day == DateTime.now.day
      date_display = "today"
    end

    agent_phone = []
    if agent&.phone.present?
      phone_prefix = agent.country_code || "+1"
      agent_phone = ["#{phone_prefix}#{agent.phone}"]
    end

    renter_phones = []
    if attendees.present?
      attendees.each do |each_renter|
        phone_prefix = each_renter.country_code || "+1"
        renter_phones << each_renter&.get_correct_phone
      end
    end

    # Send to agents
    (internal_agent_phones + agent_phone).each do |phone|
      message_body = "Hi there, the showing #{date_display} at #{@full_address} from #{self.start_datetime.in_time_zone('Eastern Time (US & Canada)').strftime("%I:%M %p")} - #{(self.start_datetime + 30.minutes).in_time_zone('Eastern Time (US & Canada)').strftime("%I:%M %p")} EST has been cancelled by the agent. Please reach out to client to reschedule \n\n- Nobee"

      send_sms(phone, message_body)
    end

    # Send to renters
    renter_phones.each do |phone|
      message_body = "Hi there, the showing #{date_display} at #{@full_address} from #{self.start_datetime.in_time_zone('Eastern Time (US & Canada)').strftime("%I:%M %p")} - #{(self.start_datetime + 30.minutes).in_time_zone('Eastern Time (US & Canada)').strftime("%I:%M %p")} EST has been cancelled by the agent. Thank you for your understanding \n\n- Nobee"

      send_sms(phone, message_body)
    end
  end
  # End Agents notification

  def generate_showing_tasks
    if start_datetime.present?
      ShowingTask.create(name: "Call super", deadline: start_datetime - 24.hours, task_source: "automated", task_type: "showing", taskable_id: self.id, taskable_type: "CalendarEvent")
      ShowingTask.create(name: "Call super", deadline: start_datetime - 2.hours, task_source: "automated", task_type: "showing", taskable_id: self.id, taskable_type: "CalendarEvent")
    end
  end

  def generate_calling_tasks
    if start_datetime.present? && event_attendances.present?
      event_attendances.each do |ea|
        ShowingTask.create(
          name: "Pre-showing",
          task_source: "automated",
          deadline: start_datetime - 3.hours,
          taskable_id: ea.id,
          taskable_type: "EventAttendance",
        )

        ShowingTask.create(
          name: "Post-showing",
          task_source: "automated",
          deadline: start_datetime + 1.hours,
          taskable_id: ea.id,
          taskable_type: "EventAttendance",
        )
      end
    end
  end

  def progress_status
    if self.event_attendances.where(status: 'confirmed').present?
      'showing_confirmed'
    elsif self.scheduled_at.present? && self.event_type == 'showing'
      'your_approval'
    elsif self.scheduled_at.present? || self.missing_info_checklist.values_at(:got_key_info, :tenants_contacted, :agent_ready).include?(true)
      'confirming_timeslots'
    else
      'showing_requested'
    end
  end

  def photo_cover_url
    photo = Photo.find_by_id(self.home.photo_cover)
    photo = self.home.photos.first if photo.blank?

    if photo.present? && photo&.image&.attached?
      if Rails.env.production?
        "#{ENV['CDN_URL']}/#{photo.image&.key}"
      else
        Rails.application.routes.url_helpers.url_for(photo&.image)
      end
    else
      BLANK_IMAGE_URL
    end
  end

  def tracking_showing_status
    if self.event_type == "completed"
      no_show_attendances = self.event_attendances.includes(:user).where.not(event_attendances: {status: ['cancelled', 'attended']})
      no_show_attendances.each do |attendance|
        attendance.user.activities.create!(
          title: "Client #{attendance.user.full_name} did not attend the showing #{self.home.full_address}",
          content: "#{calendar_event.home.full_address}, #{calendar_event.start_datetime.in_time_zone('Eastern Time (US & Canada)')}",
          activitable_id: self.id,
          activitable_type: "CalendarEvent"
        )
      end
    end
  end

  filterrific(
    default_filter_params: {  },
    # filters go here
    available_filters: [
      :sorted_by,
      :with_state,
      :with_neighborhoods,
      :with_dates,
      :with_time_range
    ],
  )


  scope :with_state, lambda { |state|
    if state == "All"
      return all
    elsif state.upcase == "NY"
      return joins(:home).where(home: {state: "NY"})
    elsif state.upcase == "MA"
      return joins(:home).where(home: {state: "MA"})
    end

    return all
  }

  scope :with_neighborhoods, lambda { |neighborhoods|
    return joins(:home).where("homes.neighborhood IN (?)", neighborhoods)
  }

  scope :with_time_range, lambda { |time_range|

    if time_range.blank? || time_range[0].blank? || time_range[1].blank?
      return all
    end


    if time_range[1].split(":")[0].to_i < 10
      return where("start_datetime::time > ? OR start_datetime::time < ?", time_range[0], time_range[1])
    else
      return where("start_datetime::time > ? AND start_datetime::time < ?", time_range[0], time_range[1])
    end
  }

  scope :with_dates, lambda { |dates|

    real_dates = dates.map{|d| Date.parse(d)}
    return where("DATE(start_datetime) IN (?)", real_dates)
  }


  private

  def send_sms(phone, message_body)
    if !Rails.env.production? && !Rails.env.test?
      puts "Phone: #{phone} - Message: #{message_body}"
      return
    end

    begin
      account_sid = ENV['TWILIO_ACCOUNT_SID']
      auth_token = ENV['TWILIO_AUTH_TOKEN']
      twilio_client = Twilio::REST::Client.new(account_sid, auth_token)
      mess = twilio_client.messages.create(
        body: message_body,
        from: ENV['TWILIO_NUMBER'],
        to: phone
      )
      if Rails.env.test?
        SentMessage.create(to: mess.to, body: message_body)
      end
    rescue Twilio::REST::RestError => error
      puts "EXCEPTION: #{error.inspect}"
    end
  end
end
