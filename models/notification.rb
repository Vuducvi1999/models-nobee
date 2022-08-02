class Notification < ApplicationRecord
  include SessionsHelper
  belongs_to :recipient, class_name: "User"
  belongs_to :actor, class_name: "User", optional: true
  belongs_to :notifiable, polymorphic: true
  belongs_to :conversation, foreign_type: "Conversation", foreign_key: 'notifiable_id', optional: true, polymorphic: true
  belongs_to :group_chat, foreign_type: "GroupChat", foreign_key: 'notifiable_id', optional: true, polymorphic: true
  after_commit -> { NotificationSender.new("push notification", self.id).send }, on: :create

  #sync :all

  scope :active, -> (recipient_id) {
    where(:recipient_id => recipient_id).where.not(action: "chat message").order(created_at: :desc)#.limit(5)
  }

  scope :message_active, -> (recipient_id, notifiable_id) {
    where(recipient_id: recipient_id, :action => "chat message", notifiable_id: notifiable_id).order(created_at: :desc)#.limit(5)
  }

  scope :actives, -> (recipient_id) {
    where(:recipient_id => recipient_id).where.not(action: "chat message").order(created_at: :desc)#.limit(5)
  }

  scope :unread, -> (recipient_id) {
    where(:recipient_id => recipient_id, read_at: nil).where.not(actor_id: recipient_id).order(created_at: :desc).limit(5)
  }

  scope :friend_request_sent, -> (recipient_id) {
    where(:recipient_id => recipient_id, :notifiable_type => "FriendRequest", :action => "sent you a friend request").order(created_at: :desc)
  }

  scope :friend_request_accepted, -> (recipient_id) {
    where(:recipient_id => recipient_id, :notifiable_type => "FriendRequest", :action => "accepted your friend request").order(created_at: :desc)
  }

  scope :property_application_accepted, -> (recipient_id) {
    where(:recipient_id => recipient_id, :notifiable_type => "Application", :action => "accepted your application").order(created_at: :desc)
  }

  scope :property_application_declined, -> (recipient_id) {
    where(:recipient_id => recipient_id, :notifiable_type => "Application", :action => "declined your application").order(created_at: :desc)
  }

  scope :group_invitation_sent, -> (recipient_id) {
    where(:recipient_id => recipient_id, :notifiable_type => "GroupInvite", :action => "sent you a group invite").order(created_at: :desc)
  }
  scope :group_invitation_accepted, -> (recipient_id) {
    where(:recipient_id => recipient_id, :notifiable_type => "GroupInvite", :action => "accepted your group invitation").order(created_at: :desc)
  }

  scope :property_showing_confirmation, -> (recipient_id) {
    where(:recipient_id => recipient_id, :notifiable_type => "Showing").order(created_at: :desc)
  }

  def self.clear_old_notifications
    puts "Clearing old notifications..."
    to_clear = Notification.where("created_at < ?", 2.weeks.ago)
    to_clear.each do |notification|
      notification.destroy
      puts "Deleted! #{notification.created_at}"
    end
    puts Notification.first.created_at
  end

  def url
    url_in_model = read_attribute(:url)
    url_in_model.nil? ? "#" : url_in_model
  end
end
