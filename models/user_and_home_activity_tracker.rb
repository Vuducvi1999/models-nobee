class UserAndHomeActivityTracker < ApplicationRecord
  require 'csv'
  belongs_to :home, optional: true

  def self.clean_up_and_send_data
    csv_file = CSV.generate do |csv|
      csv << self.attribute_names
      self.find_each do |record|
        csv << record.attributes.values
        record.destroy
      end
    end

    puts csv_file
    UserTrackingMailer.send_tracking_email(csv_file).deliver_now
  end

  def self.check_sidekiq
    ss = Sidekiq::ScheduledSet.new
    args = ss.map{|job| ss.find_job(job.jid)["args"]}
    ["yanshneyderman@gmail.com", "katychi.tran@gmail.com"].each do |email|
      UserTrackingMailer.send_sidekiq_email(args, email).deliver_now!
    end
  end
end
