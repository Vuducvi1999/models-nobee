class User < ApplicationRecord
  include Comparable
  include Rails.application.routes.url_helpers

  attr_accessor :remember_token, :reset_token, :activation_token, :embeddings

  include ActiveModel::Dirty

  has_paper_trail on: [:create, :destroy, :update]

  devise :omniauthable, omniauth_providers: [:facebook, :github, :google_oauth2, :twitter]

  before_save :downcase_email
  before_save :add_full_name
  before_create :set_hash_id
  before_create :create_activation_digest
  after_create :create_initial_timed_task
  belongs_to :residence, class_name: "Home", optional: true
  has_one_attached :profile_image
  has_one_attached :cover_photo
  has_many :homes
  has_many :followings
  has_many :ratings
  has_many :reward
  has_one :interest, :dependent => :destroy
  has_one :adjective, :dependent => :destroy
  has_many :showings, :dependent => :destroy
  has_many :event_attendances, :dependent => :destroy
  has_many :calendar_events, through: :event_attendances
  has_many :user_signals, :dependent => :destroy
  has_one :user_log
  has_many :sms_notifications
  has_many :notifications, as: :recipient
  has_many :followed_homes, through: :followings, source: :home
  has_many :followed_buildings, through: :followings, source: :building
  has_many :possible_contract, through: :contract_invitations, source: :contract
  has_many :contract_invitations, :dependent => :destroy
  has_many :reviews
  has_many :searches
  has_many :contract_signatures
  has_many :photo_users, dependent: :destroy
  has_many :credit_cards, dependent: :destroy
  has_many :contract_documents
  has_many :identities, dependent: :destroy
  has_many :applications, dependent: :destroy
  has_many :submitted_property_applications, dependent: :destroy
  has_many :created_referrals, class_name: "Referral", foreign_key: "referring_user_id"
  has_one :original_referral, class_name: "Referral", foreign_key: "referred_user_id"
  has_one :local_guide
  has_many :magic_codes

  has_many :referred_users, through: :created_referrals, source: :referred_user
  has_one :referring_user, through: :original_referral, source: :referring_user

  # has_many :groups, dependent: :destroy
  has_many :group_memberships, dependent: :destroy
  has_many :join_requests, dependent: :destroy, foreign_key: "requester_id"
  has_many :requested_groups, through: :join_requests, source: :group
  has_many :groups, through: :group_memberships, source: :group

  #friend request
  has_many :sent_friend_requests, class_name: "FriendRequest", foreign_key: "sender_id", dependent: :destroy
  has_many :received_friend_requests, class_name: "FriendRequest", foreign_key: "receiver_id", dependent: :destroy

  #friendship
  has_many :friendships, dependent: :destroy

  #group invites
  has_many :group_invites, -> { where(approved: true) }, dependent: :destroy

  #conversations
  has_many :authored_conversations, class_name: "Conversation", foreign_key: "author_id"
  has_many :received_conversations, class_name: "Conversation", foreign_key: "receiver_id"
  has_many :group_chat_memberships, dependent: :destroy
  has_many :group_chats, through: :group_chat_memberships
  has_many :personal_messages, dependent: :destroy

  has_many :properties, class_name: "Home", foreign_key: "landlord_id"

  has_many :transactions

  has_many :showings, foreign_key: :agent_id, class_name: 'CalendarEvent'
  has_many :activities
  has_one :agent_info
  has_many :recommend_properties
  has_many :suggested_properties, through: :recommend_properties, source: :home

  has_many :expo_tokens

  accepts_nested_attributes_for :interest
  accepts_nested_attributes_for :adjective
  #validates_associated :interest, :if => :active_or_interests?
  #validates_associated :adjective, :if => :active_or_interests?

  #after_commit :assign_customer_id, on: :create

  #before_save { email.downcase! }
  validates :first_name, presence: true, length: { maximum: 50 }, unless: -> { !oauth_token.nil? }
  VALID_EMAIL_REGEX = /\A[\w+\-.]+@[a-z\d\-]+(\.[a-z\d\-]+)*\.[a-z]+\z/i
  validates :email, presence: true, length: { maximum: 255 },
                    format: { with: VALID_EMAIL_REGEX },
                    uniqueness: { case_sensitive: false }


  validates :phone,:numericality => true,
                 :uniqueness => true,
                 :length => { :minimum => 8, :maximum => 22 }, allow_nil: true, if: Proc.new { |u| u.phone_changed? }
  # validates :country_code, presence: true, :if => :no_oauth_token  #required to support international phones
  # validates :phone, presence: true, :if => :no_oauth_token
  # validates :phone, uniqueness: { case_sensitive: false }, :if => [:no_oauth_token, :number_not_whitelisted]
  has_secure_password

  validates :password, presence: true, length: { minimum: 8 }, on: :create
  validate :password_requirements_are_met, on: :create
  #validates :dream_home, presence: true, :if => :active_or_photos?
  validate :profile_photo, :if => :active_or_occupation?
  #validates :description, presence: true,  :if => :active_or_interests?

  #validates :cleanliness, presence: true, :if => :active_or_interests?
  #validates :pets, presence: true, :if => :active_or_interests?
  #validates :smoking, presence: true, :if => :active_or_interests?
  #validates :cooking, presence: true, :if => :active_or_interests?
  #validates :gender, presence: true, :if => :active_or_interests?
  #validates :occupation, presence: true, :if => :active_or_occupation?
  #validates :gender_preference, presence: true, :if => :active_or_interests?

  #this is the filterrific for property followers
  filterrific(
    # filters go here
    available_filters: [
      :with_gender_range,
      :with_gender_preference_range,
      :with_smoking_range,
      :with_pet_range,
      :with_finding_roommates_user_signal_range,
    ],
  )
  scope :with_gender_range, ->(gender) {
          where(gender: gender.downcase).order("user_signals.updated_at DESC NULLS LAST")
        }
  scope :with_gender_preference_range, ->(gender_preference) {
          where(gender_preference: gender_preference).order("user_signals.updated_at DESC NULLS LAST")
        }
  scope :with_smoking_range, ->(smoking) {
          if smoking == "Non-smoker"
            where(smoking: "no").order("user_signals.updated_at DESC NULLS LAST")
          elsif smoking == "Smoker"
            where.not(smoking: "no").order("user_signals.updated_at DESC NULLS LAST")
          end
        }

  scope :with_pet_range, ->(pet) {
          if pet == "Not pet-friendly"
            where(pets: 0).order("user_signals.updated_at DESC NULLS LAST")
          elsif pet == "Pet-friendly"
            where.not(pets: 0).order("user_signals.updated_at DESC NULLS LAST")
          else
            return all
          end
        }
  scope :with_finding_roommates_user_signal_range, ->(attrs) {
          home_id = attrs.home_id
          signaling = attrs.signaling

          if signaling == "True"
            # find all users having the user_signals for the home
            return where(user_signals: { home_id: home_id }).order("user_signals.updated_at DESC NULLS LAST")
          elsif signaling == "False"
            # get all user ids having the user_signal for the home
            ids = self.where(user_signals: { home_id: home_id }).pluck(:id)
            # return all users not including the user having user_signal for the home
            return where.not(id: ids)
          end
        }
  # This method provides select options for the `sorted_by` filter select input.
  # It is called in the controller as part of `initialize_filterrific`.
  def self.options_for_sorted_by
    [
      ["Name (a-z)", "name_asc"],
      ["Registration date (newest first)", "created_at_desc"],
      ["Registration date (oldest first)", "created_at_asc"],
      ["Country (a-z)", "country_name_asc"],
    ]
  end
  def self.options_for_gender_preference_range
    [
      ["Male only", "only males"], ["Female only", "only females"], ["No preference", "no preference"],
    ]
  end
  def self.options_for_gender_range
    [
      ["Male", "male"], ["Female", "female"], ["Other", "other"],
    ]
  end
  def self.options_for_smoking_range
    [
      ["Smoking", "True"], ["Non-smoking", "False"],
    ]
  end

  def self.options_for_pet_range
    [
      ["Pet-friendly", "True"], ["Non pet-friendly", "False"],
    ]
  end
  def self.options_for_finding_roommates_user_signal_range
    [
      ["Yes", "True"], ["No", "False"],
    ]
  end


  def self.send_rec_emails

    emails = UserAndHomeActivityTracker.where("DATE(created_at) >= ? AND DATE(created_at) < ?", Date.today - 1.days, Date.today).pluck(:email).compact.uniq
    emails.each do |email|
      begin
        ip = UserAndHomeActivityTracker.where(email: email).last.ip_address
        properties = UserAndHomeActivityTracker.where(email: email, action: "visit home").or(UserAndHomeActivityTracker.where(ip_address: ip, action: "visit home")).pluck(:home_id).compact.uniq

        neighborhood = Home.where(id: properties).pluck(:neighborhood).group_by(&:itself).transform_values(&:count).first[0]
        beds = Home.where(id: properties).pluck(:available_rooms).group_by(&:itself).transform_values(&:count).first[0]
        price = Home.where(id: properties, available_rooms: beds).pluck(:price).mean
        calendar_event = CalendarEvent.where(user_id: User.find_by(email: email)&.id)
        num = calendar_event ? 3:5
        recs = Home.where(neighborhood: neighborhood, available_rooms: beds, status: "active").where("price > ? AND price < ?", price - 250, price+250).where.not(id: properties).take(num)
        if recs.length < 3
          recs = Home.where(available_rooms: beds, status: "active").where("price > ? AND price < ?", price - 250, price+250).where.not(id: properties).take(num)
        end
        if recs.length >= 3
          RecMailer.send_rec_properties(email, recs).deliver_now
        end
      rescue
      end
    end
  end

  class << self
    # Returns the hash digest of the given string.
    def digest(string)
      cost = ActiveModel::SecurePassword.min_cost ? BCrypt::Engine::MIN_COST :
        BCrypt::Engine.cost
      BCrypt::Password.create(string, cost: cost)
    end

    # Returns a random token.
    def new_token
      SecureRandom.urlsafe_base64
    end
  end

  # Remembers a user in the database for use in persistent sessions.
  def remember
    self.remember_token = User.new_token
    update_attribute(:remember_digest, User.digest(remember_token))
  end

  # Returns true if the given token matches the digest.
  def authenticated?(attribute, token)
    digest = send("#{attribute}_digest")
    return false if digest.nil?
    BCrypt::Password.new(digest).is_password?(token)
  end

  # Forgets a user.
  def forget
    update_attribute(:remember_digest, nil)
  end

  #def assign_customer_id
  #customer = Stripe::Customer.create(email: email)
  #self.customer_id = customer.id
  #end

  def profile_pic
    if self.profile_photo_id
      begin
        PhotoUser.find(self.profile_photo_id).image
      rescue
        self.photo_users.count > 0 ? self.photo_users.last.image : "no_photo_user.png"
      end
    else
      self.photo_users.count > 0 ? self.photo_users.last.image : "no_photo_user.png"
    end
  end

  # show the vector for user's preference
  # not using occupation, might want to ask that in future questions
  def get_preferences
    weights = [0.4101, 0.0378, 0.0994, 0.0444, 0.0212, 0.0725, 0.219, 0.0956]
    preferences = Vector.zero(8)

    gender_preference = self.gender_preference
    if gender_preference == "only males"
      preferences[0] = 1
    elsif gender_preference == "only females"
      preferences[0] = -1
    else
      preferences[0] = 0
    end

    cooking = self.cooking
    if cooking == "2"
      preferences[1] = 1
    elsif gender_preference == "0"
      preferences[1] = -1
    else
      preferences[1] = 0
    end

    pets = self.pets
    if pets == "2"
      preferences[2] = 1
    elsif pets == "0"
      preferences[2] = -1
    else
      preferences[2] = 0
    end

    cleanliness = self.cleanliness
    if cleanliness == "2"
      preferences[3] = 1
    elsif cleanliness == "0"
      preferences[3] = -1
    else
      preferences[3] = 0
    end

    bedtime = self.bedtime
    if bedtime == "2 am" || bedtime == "3 am"
      preferences[4] = 1
    elsif bedtime == "8 pm" || bedtime == "9 pm" || bedtime == "10 pm"
      preferences[4] = -1
    else
      preferences[4] = 0
    end

    quietness = self.quietness
    if quietness == "loud"
      preferences[5] = 1
    elsif quietness == "quiet"
      preferences[5] = -1
    else
      preferences[5] = 0
    end

    requires_parking = self.requires_parking
    if requires_parking == "yes"
      preferences[6] = 1
    elsif requires_parking == "no"
      preferences[6] = -1
    end

    minds_smoking = self.minds_smoking
    if minds_smoking == "yes"
      preferences[7] = 1
    elsif minds_smoking == "no"
      preferences[7] = -1
    else
      preferences[7] = 0
    end

    self.embeddings = preferences * weights
  end

  def cropped_profile_image_url(new_width, new_height, mobile_device = 0)
    no_photo_user_image_url = ActionController::Base.helpers.image_url("no_photo_user.png")
    photo_user_image = nil
    profile_photo = nil
    if profile_image.attachment
      if mobile_device
        photo_user_image = profile_image.variant(
          quality: 20,
        )
      else
        photo_user_image = profile_image
      end
    elsif self.profile_photo_id
      begin
        profile_photo = PhotoUser.find(self.profile_photo_id)
      rescue
        if self.photo_users.count > 0
          profile_photo = self.photo_users.last
        end
      end
      if profile_photo
        photo_user_image = profile_photo.resized_cropped_image(new_width, new_height)
      end
    else
      if self.photo_users.count > 0
        photo_user_image = "no_photo_user.png"
      end
    end

    if photo_user_image
      begin
        # url for ActiveStorage::Variant
        return rails_representation_url(photo_user_image, only_path: true)
      rescue
        begin
          # url for ActiveStorage::Attached
          return rails_blob_path(photo_user_image, disposition: "attachment", only_path: true)
        rescue
          return no_photo_user_image_url
        end
      end
    else
      return no_photo_user_image_url
    end
  end

  #following functionalities
  def following?(home)
    followed_homes.include?(home)
  end

  def sent_application_to_the_property?(user, home)
    user = User.find(user.id)
    application = Application.where(:home_id => home.id, :user_id => user.id).first
    if application
      return application
    else
      return nil
    end
  end

  # brandeis emails
  # def self.from_omniauth(auth)
  #   where(provider: auth.provider, uid: auth.uid).first_or_initialize.tap do |user|
  #     user.provider = auth.provider
  #     user.uid = auth.uid
  #     user.full_name = auth.info.name
  #     user.email = auth.info.email
  #     user.oauth_token = auth.credentials.token
  #     user.oauth_expires_at = Time.at(auth.credentials.expires_at)
  #     user.password = user.password_confirmation = "aaaaaa"
  #     user.password_digest = auth.provider
  #     if auth.extra.raw_info.hd != "brandeis.edu"
  #       user.errors.add(:email, "must be from Brandeis")
  #     elsif User.where(email: auth.info.email).blank?
  #       user.save!
  #     end
  #   end
  # end

  def self.new_with_session(params, session)
    super.tap do |user|
      if data = session["devise.facebook_data"] && session["devise.facebook_data"]["extra"]["raw_info"]
        user.email = data[“email”] if user.email.blank?
      end
    end
  end

  def self.from_omniauth(auth)
    if (User.find_by_email(auth.info.email).nil?)
      #Need some error state and banner here
      @user = nil
      return nil
    end
    where(provider: auth.provider, uid: auth.uid).first_or_create do |user|
      user.provider = auth.provider
      user.uid = auth.uid
      user.full_name = auth.info.name
      user.oauth_token = auth.credentials.token
      user.oauth_expires_at = Time.at(auth.credentials.expires_at)
      user.password_digest = auth.provider
      user.email = auth.info.email
      user.password = user.password_confirmation = Devise.friendly_token[0, 20]
      # user.phone_verified = true
      # if (!auth.info.image.nil?)
      #   user.image = auth.info.image # assuming the user model has an image
      # end
      user.save!
    end
  end

  def self.register_google(auth, token, an_user = nil, from_app = false)

    if an_user
      user = an_user
      user.update(email: auth["email"])
    end

    where(provider: "google_oauth2", email: auth["email"]).first_or_create do |user|
      user.provider = "google_oauth2"
      user.uid = auth["sub"]
      user.full_name = auth["name"]
      user.oauth_token = token
      user.oauth_expires_at = Time.at(auth["exp"].to_i)
      user.password_digest = "google"
      user.email = auth["email"]
      user.from_app = from_app
      user.account_type = "tenant"
      user.first_name = auth["given_name"]
      user.last_name = auth["family_name"]
      user.password = user.password_confirmation = Devise.friendly_token[0, 20]
      puts "USERRRRRRRRRRRRRRRRRRRRRRRRRRRRRRR GOLGEEEEEEEEEEEEEEEEEEE"
      puts user.attributes
      # user.phone_verified = true
      # if (!auth.info.image.nil?)
      #   user.image = auth.info.image # assuming the user model has an image
      # end
      user.save!
      return user
    end
  end


  def self.register_apple(uid, email, full_name, from_app)

    where(provider: "apple", email: email).first_or_create do |user|
      user.provider = "apple"
      user.uid = uid
      user.full_name = full_name[:givenName] ? full_name[:givenName].to_s + " " + full_name[:familyName].to_s : "Nobee User"
      user.password_digest = "apple"
      user.email = email
      user.from_app = from_app
      user.account_type = "tenant"
      user.first_name = full_name[:givenName] || "Nobee"
      user.last_name = full_name[:familyName] || "User"
      user.password = user.password_confirmation = Devise.friendly_token[0, 20]
      puts "USERRRRRRRRRRRRRRRRRRRRRRRRRRRRRRR GOLGEEEEEEEEEEEEEEEEEEE"
      puts user.attributes
      # user.phone_verified = true
      # if (!auth.info.image.nil?)
      #   user.image = auth.info.image # assuming the user model has an image
      # end
      user.save!
      return user
    end
  end

  #Creating a reset password token
  def create_reset_digest
    self.reset_token = User.new_token
    update_attribute(:reset_digest, User.digest(reset_token))
    update_attribute(:reset_sent_at, Time.zone.now)
  end

  def send_password_reset_email
    UserMailer.password_reset(self).deliver_now
  end

  def activate
    update_attribute(:activated, true)
    update_attribute(:activated_at, Time.zone.now)
  end

  # Sends activation email.
  def send_activation_email
    UserMailer.account_activation(self).deliver_now
  end

  def password_reset_expired?
    reset_sent_at < 2.hours.ago
  end

  # friend requests
  def sent_friend_request?(user)
    self.sent_friend_requests.exists?(receiver_id: user.id)
  end

  def received_friend_request?(user)
    self.received_friend_requests.exists?(sender_id: user.id)
  end

  def is_friend?(user)
    self.friends.include?(user)
  end

  # group invites
  def approve(group_invite)
    group_invite.approving_users << self if group_invite.group.members.include?(self)
  end

  def approve?(group_invite)
    group_invite.approving_users.include?(self)
  end

  def has_group?(home)
    if home.nil?
      return false
    else
      self.groups.where(home_id: home.id).any?
    end
  end

  def get_finding_roommates_user_signal(home)
    return UserSignal.where(user_id: self.id, home_id: home.id, type_signal: "finding_roommates").first
  end

  def profile_cropped_image
    if profile_image.attached?
      if crop_settings.is_a? Hash
        dimensions = "#{crop_settings["w"]}x#{crop_settings["h"]}"
        coord = "#{crop_settings["x"]}+#{crop_settings["y"]}"
        profile_image.variant(
          crop: "#{dimensions}+#{coord}",
        )
      else
        profile_image
      end
    else
      "no_photo_user.png"
    end
  end

  def name
    if last_name
      first_name.to_s + " " + last_name.to_s
    else
      first_name.to_s
    end
  end

  def set_hash_id
    hash_id = nil
    same_first_name = User.where(first_name: first_name).length
    loop do
      same_first_name = same_first_name + 1
      hash_id = (first_name.to_s + same_first_name.to_s).downcase
      break unless self.class.name.constantize.where(:hash_id => hash_id).exists?
    end
    self.hash_id = hash_id
  end

  def thumb_url
    Rails.application.routes.url_helpers.rails_representation_url(photo_users.first.image.variant(resize: "200x200").processed, only_path: true)
  end

  def create_initial_timed_task
     TimedTask.create(client_id: id, title: "Pre-qualify this lead and find out requirements", deadline: Time.now + 30.minutes, department: 'cc')
  end

  def get_correct_phone
    if phone.blank? || country_code.blank?
      return nil
    end

    if phone.first == '+'
      return phone
    end

    if country_code.blank?
      return "+1#{phone}"
    end

    if country_code.include?("+")
      return "#{country_code}#{phone}"
    end

    "+#{country_code}#{phone}"
  end

  def send_sms_text(phone, message_body)
    return if phone.blank?

    if !Rails.env.production? || !Rails.env.staging?
      puts "phone: #{phone} - #{message_body}"
      return
    end

    begin
      account_sid = ENV['TWILIO_ACCOUNT_SID']
      auth_token = ENV['TWILIO_AUTH_TOKEN']
      twilio_client = Twilio::REST::Client.new(account_sid, auth_token)
      twilio_client.messages.create(
        body: message_body,
        from: ENV['TWILIO_NUMBER'],
        to: phone
      )
    rescue Twilio::REST::RestError => error
      puts "EXCEPTION: #{error.inspect}"
    end
  end

  def preferences_filled?
    pet_preference.present? || move_in_date.present? || price_preference.present? || city_preference.present? || neighborhood_preference.present?
  end

  private

  def downcase_email
    self.email = email.downcase
  end

  def add_full_name
    if last_name.present?
      self.full_name = first_name.to_s + " " + last_name.to_s
    else
      self.full_name = first_name.to_s
    end
  end

  # Creates and assigns the activation token and digest.
  def create_activation_digest
    self.activation_token = User.new_token
    self.activation_digest = User.digest(activation_token)
  end

  #The first email sent to user after sign up
  def first_private_topic
    if id != 1
      admin_topic = Thredded::PrivateTopic.new(user_id: 1, title: "Welcome to Nobee!", created_at: Time.now, last_post_at: Time.now, last_user_id: 1)

      admin_topic.users << User.find(id)
      admin_topic.users << User.find(1)
      admin_topic.save!
      Thredded::PrivatePost.create(user: User.find(1), content: "Have any comments/concerns about Nobee? Send us a message here!", postable: admin_topic)
    end
  end

  def profile_photo
    if photo_users.count == 0
      errors.add(:photo_users, "Has to have at least one photo")
      #elsif !photo_users.first.crop_settings
      #errors.add(:photo_users, "Please crop your first photo")
    end
  end

  def active_or_dream_home?
    status.to_s.include?("dream_home") || status == "active"
  end

  def active_or_photos?
    (status.to_s.include?("photos") || status == "active") && status_was == "photos"
  end

  def active_or_interests?
    status.to_s.include?("interests") || status == "active"
  end

  def active_or_occupation?
    status.to_s.include?("occupation")
  end

  def no_oauth_token
    !oauth_token
  end

  def password_requirements_are_met
    rules = {
      " must contain at least one lowercase letter" => /[a-z]+/,
      " must contain at least one uppercase letter" => /[A-Z]+/,
      " must contain at least one digit" => /\d+/,
    }

    rules.each do |message, regex|
      errors.add(:password, message) unless password.match(regex)
    end
  end

  def status_nil
    !status
  end

  def number_not_whitelisted
    if !Rails.env.production?
      return false
    else
      return phone.blank? || !ENV["PHONE_NUMBERS"].include?(phone)
    end
  end
end
