class SmsNotification < ApplicationRecord
  belongs_to :user #sender
  validates :content, presence: true

  after_commit :fanout, on: [:create]

  # send sms to all other users in a same topic
  def fanout
    private_topic = private_post.postable
    private_users = private_topic.private_users # user_ids in a same topic

    private_users.each do |private_user|
      if private_user.id != user.id # do not send sms to sender
        # private_user != full user => get a full user attr from db
        send_sms(User.find(private_user.id))
      end
    end
  end

  private

  def twilio_from_phone
    twilio_from_phone = ENV['TWILIO_PHONE_NUMBER']
    return twilio_from_phone
  end

  def send_sms(user_phone)
    @from_phone = twilio_from_phone
    # our job to provide accurate phone, Twilio does not support that
    @to_phone = user_phone # preferably US, Canadian phones

    # skip user without phone
    if @to_phone == nil
      return
    end

    # sms notification
  end
end
