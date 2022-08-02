class GroupChat < ApplicationRecord
  include ApplicationHelper

  belongs_to :home, optional: true
  has_many :group_chat_memberships, dependent: :destroy
  has_many :members, through: :group_chat_memberships, source: :user, validate: false
  has_many :personal_messages, dependent: :destroy, as: :messageable
  has_many :notifications, as: :notifiable
  default_scope { order(updated_at: :desc) }

  def title(current_user)
    self[:name]
  end

  def remove_user(user)
    # assume user is a member of the group chat
    raise "User is not a member of group chat" unless self.members.include?(user)
    self.members.delete(user)
  end

  def add_user(user)
    unless self.members.include?(user)
      self.members << user
    end
  end

  def img(current_user)
    "no_photo_user.png"
  end

  def url(current_user)
    if home_id
      return "/group_chats/#{self.id}?home_id=#{home_id}"
    else
      return "/group_chats/#{self.id}"
    end
  end

  def ID(current_user)
    self.id
  end

  def type
    'group_chat'
  end

  def last_message
    self.personal_messages.last
  end

  def seen_by?(user)
    if self.personal_messages.count == 0
      true
    else
      self.last_message.seen.key?(user.id) || self.last_message.user == user
    end
  end

  def get_all_messages_in_page(page_number)
    self.personal_messages.with_attached_attachment.order(created_at: :desc).page(page_number).per(10)
  end

  def seen_list(current_user)
    if self.personal_messages.count == 0
      return ""
    end

    ids = self.last_message.seen.keys
    users = ids.select{|id| id != current_user.id}.map{|id| User.find(id).name}

    if users.any?
      to_return = "Seen by "
      to_return += users.join(", ")
    else
      to_return = ''
    end

    return to_return
  end

  # find by messageable id
  def self.find_first(messageable_id, home_id)
    if home_id
      group_chat = GroupChat.find_by(id: messageable_id, home_id: home_id)
    else
      group_chat = GroupChat.find_by(id: messageable_id, home_id: nil)
    end

    return group_chat
  end

  def self.find_first_or_new(messageable_id, home_id, user_id)
    if home_id
      group_chat = GroupChat.find_first(messageable_id, home_id)
    else
      group_chat = GroupChat.find_first(messageable_id, nil)
    end

    if group_chat.nil?
      if home_id
        group_chat = GroupChat.new(user_id: user_id, home_id: home_id)
      else
        group_chat = GroupChat.new(user_id: user_id)
      end
    end

    return group_chat
  end

  # create an object if not exist. DOES NOT SAVE to database
  # home_id parameter will be passed when user click the inbox button on the property page
  # => a property-based conversation is created for better user experience
  def self.find_first_or_create(user_ids)

    group_chat = GroupChat.find_by(member_ids_array: user_ids.sort)

    if group_chat.nil?
      group_chat = GroupChat.new(member_ids_array: user_ids.sort)
      group_chat.member_ids = user_ids
      group_chat.pending = nil

      if user_ids.length == 1
        group_chat.chat_type = "chat with admin"
      end

      group_chat.messages_last_updated = Time.current
      group_chat.save

      if user_ids.length == 1
        group_chat.personal_messages.create(user_id: 1, body: "Welcome to Nobee! We are happy to answer any questions you have.")
      end
      
    end

    return group_chat
  end


end
