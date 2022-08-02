class Conversation < ApplicationRecord
  belongs_to :author, class_name: "User"
  belongs_to :receiver, class_name: "User"
  belongs_to :home, optional: true
  validates :author, uniqueness: { scope: [:receiver, :home_id] }
  validate :no_duplicate_conversation, on: :create

  has_many :personal_messages, dependent: :destroy, as: :messageable
  has_many :notifications, as: :notifiable
  default_scope { order(updated_at: :desc) }

  scope :participating, ->(user) do
          where("(conversations.author_id = ? OR conversations.receiver_id = ?)", user.id, user.id)
        end

  def members
    if author == receiver
      [author]
    else
      [author, receiver]
    end
  end

  def no_duplicate_conversation
    if Conversation.exists?(author_id: receiver_id, receiver_id: author_id, home_id: nil) &&
       Conversation.exists?(author_id: receiver_id, receiver_id: author_id, home_id: home_id) ||
       Conversation.exists?(author_id: author_id, receiver_id: receiver_id, home_id: nil) &&
       Conversation.exists?(author_id: author_id, receiver_id: receiver_id, home_id: home_id)
      errors.add(:base, "This conversation already exists")
    end
  end

  # return the other user
  def with(current_user)
    author == current_user ? receiver : author
  end

  # show conversation name with respect to current_user
  def title(current_user)
    if home_id
      return self.home.title
    else
      other = self.with(current_user)
      if other
        return other.name
      end
    end
  end

  # find by two ids
  def self.find_first(user1_id, user2_id, home_id)
    if home_id
      conversation = Conversation.find_by(author_id: user1_id, receiver_id: user2_id, home_id: home_id) ||
                     Conversation.find_by(author_id: user2_id, receiver_id: user1_id, home_id: home_id)
    else
      conversation = Conversation.find_by(author_id: user1_id, receiver_id: user2_id, home_id: nil) ||
                     Conversation.find_by(author_id: user2_id, receiver_id: user1_id, home_id: nil)
    end

    return conversation
  end

  def url(current_user)
    other = self.with(current_user)
    if home_id
      return "/conversations/#{other.id}?home_id=#{home_id}"
    else
      return "/conversations/#{other.id}"
    end
  end

  def img(current_user)
    other = self.with(current_user)
    if other
      other.cropped_profile_image_url(50, 50)
    end
  end

  # get ID of the receiver
  def ID(current_user)
    self.with(current_user).id
  end

  # Conversation or Group Chat
  def type
    "conversation"
  end

  # create an object if not exist. SAVE to database
  def self.find_first_or_create(user1_id, user2_id, home_id)
    puts "HOMEID"
    puts home_id
    if home_id
      conversation = Conversation.find_first(user1_id, user2_id, home_id)
    else
      conversation = Conversation.find_first(user1_id, user2_id, nil)
    end
    puts user2_id
    if conversation.nil?
      if home_id
        conversation = Conversation.create!(author_id: user1_id, receiver_id: user2_id, home_id: home_id)
      else
        conversation = Conversation.create!(author_id: user1_id, receiver_id: user2_id)
      end
    end

    return conversation
  end

  # create an object if not exist. DOES NOT SAVE to database
  # home_id parameter will be passed when user click the inbox button on the property page
  # => a property-based conversation is created for better user experience
  def self.find_first_or_new(user1_id, user2_id, home_id)
    if home_id
      conversation = Conversation.find_first(user1_id, user2_id, home_id)
    else
      conversation = Conversation.find_first(user1_id, user2_id, nil)
    end

    if conversation.nil?
      if home_id
        conversation = Conversation.new(author_id: user1_id, receiver_id: user2_id, home_id: home_id)
      else
        conversation = Conversation.new(author_id: user1_id, receiver_id: user2_id, home_id: nil)
      end
    end

    return conversation
  end

  def self.search_by_name(username, current_user)
    username.downcase!
    matching_users = User.where("lower(full_name) like ? or lower(full_name) like ?", "% #{username}%", "#{username}%")
    (matching_users.map { |user|
      Conversation.find_first_or_new(user.id, current_user.id, nil)
    } +
     current_user.group_chats.joins(:members).where("lower(users.full_name) like ? or lower(users.full_name) like ?", "% #{username}%", "#{username}%").distinct).sort_by { |conversation| conversation.updated_at.nil? ? DateTime.new(1999, 1, 1, 0, 0, 0) : conversation.updated_at }.reverse!
  end

  def self.get_all_conversations_for(current_user)
    (Conversation.participating(current_user) + current_user.group_chats).sort_by { |conversation| conversation.updated_at }.reverse!
  end

  def self.get_all_conversations_and_actual_groupchats_for(current_user)
    (Conversation.participating(current_user) + current_user.group_chats.where(has_messages: true)).sort_by { |conversation| conversation.updated_at }.reverse!
  end

  def last_message
    self.personal_messages.last
  end

  def get_all_messages_in_page(page_number)
    # ative storage eager loading with includes attachment for less query
    self.personal_messages.with_attached_attachment.order(created_at: :desc).page(page_number).per(20)
  end

  def seen_by?(user)
    if self.personal_messages.count == 0
      true
    else
      self.last_message.seen.key?(user.id) || self.last_message.user == user
    end
  end

  def seen_list(current_user)
    if self.personal_messages.count == 0
      return ""
    end

    ids = self.last_message.seen.keys
    users = ids.select { |id| id != current_user.id }.map { |id| User.find(id).name }

    if users.any?
      to_return = "Seen by "
      to_return += users.join(", ")
    else
      to_return = ""
    end

    return to_return
  end
end
