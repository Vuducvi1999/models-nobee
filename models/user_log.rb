class UserLog < ApplicationRecord
  belongs_to :user
  def self.mail_log_file(email)

    f = File.new("log.txt", "w+")
    if UserLog.first
      f.write(UserLog.first.log)
      UserLog.first.destroy
    end
    f.close
    LogfileMailer.send_log_file(email).deliver_now
  end
end
