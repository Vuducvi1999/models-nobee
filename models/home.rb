require "csv"

class Home < ApplicationRecord
  include ActiveModel::Dirty
  include ActiveModel::Validations

  has_paper_trail on: [:create, :destroy, :update]

  @@room_number = 0
  @@coords = []
  define_attribute_method :available_rooms
  before_create :set_hash_id
  belongs_to :user
  belongs_to :landlord, class_name: "User", optional: true
  belongs_to :owner, optional: true
  has_many :followings, :dependent => :destroy
  has_many :users, through: :followings
  has_one :option, :dependent => :destroy
  has_one :contract
  belongs_to :cover, class_name: "Photo", foreign_key: :photo_cover, optional: true
  has_many :ratings
  has_many :photos, -> { order(position: :asc) }, :dependent => :destroy
  has_many :rooms, :dependent => :destroy, inverse_of: :home
  has_many :calendar_events, :dependent => :destroy
  has_many :user_signals, :dependent => :destroy
  has_many :groups, :dependent => :destroy
  has_many :property_questions, :dependent => :destroy
  has_many :submitted_property_applications, :dependent => :destroy
  has_many :tenants, class_name: "User", foreign_key: "residence_id"
  has_many :list_members, class_name: "User"
  has_many :conversations, :dependent => :destroy
  has_many :group_chats, :dependent => :destroy
  has_many :transactions
  has_many :applicants
  belongs_to :building, optional: true, touch: true

  accepts_nested_attributes_for :option
  accepts_nested_attributes_for :photos
  accepts_nested_attributes_for :rooms
  has_one_attached :application_form
  has_one_attached :video
  has_one_attached :video_thumbnail
  has_one_attached :custom_application

  validates :address, presence: true
  #uniqueness: { case_sensitive: false }
  validates :latitude, presence: true
  validates :longitude, presence: true
  validate :has_to_agree
  validates :price, presence: true, numericality: true, :if => :active?
  # validate :id_photo
  # validate :lease_photo
  validates :title, presence: { message: "Title can't be blank" }, length: { maximum: 140 }, :if => :active_or_photos?
  #validates :description, presence: { message: "Description can't be blank" }, :if => :active_or_photos?
  validates :furnished, inclusion: { in: [true, false] }, :if => :active_or_house_info?
  #validates :sublet_allowed, inclusion: { in: [ true, false ] }, :if => :active_or_lease?
  #validates :capacity, presence: true, numericality: true
  #validates :entire_home, inclusion: { in: [ true, false ] }
  validates :available_rooms, numericality: true, :if => :active_or_house_info?

  validates :total_rooms, numericality: true, :if => :active_or_house_info?
  validates_numericality_of :available_rooms, less_than_or_equal_to: ->(home) { home.total_rooms }, message: "Number of available rooms must be less than or equal to the number of total rooms", if: :active_or_rooms_and_total_rooms?
  validates :total_bathrooms, numericality: true, :if => :active_or_house_info?
  validates_numericality_of :total_bathrooms, greater_than_or_equal_to: 1, message: "^Please create a bathroom", :if => :active_or_house_info?
  # validates :price, numericality: true, :if => :active_or_lease?
  validates :security_deposit_price, numericality: true, :if => :active_or_lease?
  validates :start_date, presence: true, :if => :active_or_lease?
  #validates :end_date, presence: true, :if => :active_or_lease?
  validate :start_date_before_end_date, :if => :active_or_lease?
  validate :need_property_type
  validate :need_poster_type
  # validate :amenities_one_valid, :if => :active_or_amenities_one?
  #validate :amenities_two_valid, :if => :active_or_amenities_two?

  #validate :pictures_for_each_room, :if => :active_or_house_info?

  validate :at_least_one_bedroom, :if => :active_or_house_info?
  #validates_associated :photos

  def updated_address
    if address && (address.include? "MA, USA")
      address.sub! "MA, USA", "Massachusetts"
    end
    return address
  end

  geocoded_by :updated_address
  #before_validation :geocode, on: [:create]
  #before_validation :delay
  #before_create :distance_matrix

  def delay
    sleep 1
  end

  def self.active_on_map(map_bounds)
    #Rails.cache.fetch(map_bounds.to_s) do
      with_coordination(map_bounds).where(status: "active")
    #end
  end

  #We need to make sure a home has 2 photos of eacg bedroom + kitchen+ bathroom+ living_room
  def more_than_one_photo_cont
    if !user.photo_exemption?
      if photos.select { |p| p.is_bathroom == true }.count < 1 || photos.select { |p| p.is_kitchen == true }.count < 1 || photos.select { |p| p.is_living_room == true }.count < 1 || photos.select { |p| p.is_bedroom == true }.count < 2 * available_rooms
        return false
      end
    end
    return true
  end

  def rooms_cont
    if rooms.pluck(:price) && rooms.pluck(:price).min && rooms.count >= available_rooms
      return true
    else
      return false
    end
  end

  def distance_matrix(mode = "default")
    destinations = ["hospital", "supermarket", "airport"]
    data_set = []
    @client = GooglePlaces::Client.new(ENV["GOOGLE_KEY"])
    matrix = GoogleDistanceMatrix::Matrix.new
    matrix.configure do |config|
      config.google_api_key = ENV["GOOGLE_KEY"]
      config.units = "imperial"
    end
    here = GoogleDistanceMatrix::Place.new lng: longitude, lat: latitude
    matrix.origins << here
    destinations.each_with_index do |d, index|
      result = @client.spots_by_query(d + " near " + address, radius: 10000)
      coords = result[0].json_result_object["geometry"]["location"]
      matrix.configuration.mode = "driving"
      dest = GoogleDistanceMatrix::Place.new lng: coords["lng"], lat: coords["lat"]
      matrix.destinations << dest
      matrix.reset!
      data_set[index] = matrix.data
      matrix.destinations.pop
    end
    # in miles and minutes
    self.closest_hospital = to_integer(data_set[0][0][0].duration_text)
    self.closest_supermarket = to_integer(data_set[1][0][0].duration_text)
    self.closest_airport = to_integer(data_set[2][0][0].duration_text)
    if mode == "update"
      self.save(validate: false)
    end
  end

  def self.clear_stale
    stale_homes = Home.where("DATE(created_at) < DATE(?)", Date.yesterday).where.not(status: "active")
    stale_homes.map(&:destroy)
  end

  def self.sync_with_ygl
    SyncYglJob.set(wait: 6.hours).perform_later
    SyncYglJob.set(wait: 12.hours).perform_later
    SyncYglJob.set(wait: 18.hours).perform_later
  end

  def create_reviews(n_reviews = 5, user_id = User.last.id, description = "Best house", cleanliness = 5, accuracy = 5, spaciousness = 5, convenience = 5)
    n_reviews.times do |t|
      self.reviews.create(user_id: user_id, description: description, cleanliness: cleanliness, accuracy: accuracy, spaciousness: spaciousness, convenience: convenience)
    end
  end

  def self.clear_with_few_photos
    #few_photos = Home.all.select { |h| h.photos.count < 4 }
    #few_photos.map(&:destroy)
  end

  def self.options_for_furnished
    [
      ["Yes", 1],
      ["No", 0],
    ]
  end
=begin
  def self.price_graph
    group = Hash.new(10)
    min = minimum(:price)
    step = (maximum(:price) - min)/10
    pluck(:price).each do |price|
      group_index = ((price - min) / step).ceil.clamp(1, 10) - 1
      group[group_index] += 1
    end
    group
  end
=end

  filterrific(
    default_filter_params: {  },
    # filters go here
    available_filters: [
      :sorted_by,
      :with_availability_range,
      :with_price_range,
      :with_total_rooms_range,
      :with_available_rooms_range,
      :with_fee_type,
      :with_total_bathrooms_range,
      :with_private_bathrooms_range,
      :with_furnished,
      :with_distance_range,
      :with_driving_duration_range,
      :with_bicycling_duration_range,
      :with_transit_duration_range,
      :with_walking_duration_range,
      :with_pets_allowed,
      :with_free_parking,
      :with_subletters_allowed,
      :with_in_unit_laundry,
      :with_central_ac,
      :with_wifi,
      :with_dish_washer,
      :with_fireplace,
      :with_garbage_disposal,
      :with_elevator,
      :with_pool,
      :with_gym,
      :with_wheelchair,
      :with_hot_tub,
      :with_closet,
      :with_porch,
      :with_lawn,
      :with_patio,
      :with_storage,
      :with_refrigerator,
      :with_stove,
      :with_microwave,
      :with_coffee_maker,
      :with_backyard,
      :with_lockbox,
      :with_smoke_detector,
      :with_fire_extinguisher,
      :with_soundproof,
      :with_intercom,
      :with_gated,
      :with_doorman,
      :with_studio,
      :with_apartment,
      :with_split_apartment,
      :with_room_for_rent,
      :with_dogs_allowed,
      :with_cats_allowed,
      :with_active,
      :with_neighborhoods,
      :with_subway_lines
    ],
  )

  # sort options go here, default ascending
  scope :sorted_by, lambda { |sort_key|
    case sort_key.to_i
    when 1
      order("homes.created_at desc")
    when 2
      order("homes.price asc")
    when 3
      order("homes.price desc")
    when 4
      order("homes.available_rooms asc")
    when 5
      order("homes.available_rooms desc")
    when 6
      order("homes.total_bathrooms asc")
    when 7
      order("homes.total_bathrooms desc")
    when 8
      order(Arel.sql("abs(homes.latitude - ?) + abs(homes.longitude - ?)"), @@coords[0], @@coords[1])
    when 9
      order("homes.neighborhood asc")
    when 10
      order("homes.neighborhood desc")
    else
      raise(ArgumentError, "Invalid sort option: #{sort_key.inspect}")
    end
  }

  def self.set_coords(coords)
    @@coords = coords
  end

  def self.set_room_number(n)
    @@room_number = n
  end

  # date range of availability, can choose both start and end
  #scope :with_date_margin, lambda { |date_margin_attrs|
  #column = "#{date_margin_attrs.to_s[5..-7]}".to_sym

  #if date_margin_attrs.min.blank? && date_margin_attrs.max.blank?

  #elsif date_margin_attrs.min.blank?
  #  date_margin_max=date_margin_attrs.max.to_i
  #elsif date_margin_attrs.max.blank?
  #  date_margin_min=date_margin_attrs.min.to_i
  #  else
  #  date_margin_min=date_margin_attrs.min.to_i
  #date_margin_max=date_margin_attrs.max.to_i
  #end
  #if !start_date && !end_date
  #  return all
  #elsif !start_date
  #  return where("end_date <= ?", end_date+date_margin_max.to_i)
  #elsif !end_date
  #  return where("start_date >= ?", start_date-date_margin_min.to_i)
  #end

  #where("start_date >= ? AND end_date <= ?", start_date-date_margin_min.to_i, end_date+date_margin_max.to_i)
  #}

  scope :with_location, lambda { |location_attrs|
    location = location_attrs.loc
    if location.nil? || location.empty?
      return all
    else
      universities = ENV["UNIVERSITIES"].split(", ")
      university_centers = ENV["UNIVERSITY_CENTERS"].split(" | ")
      universities.each_with_index do |uni, ind|
        if location.include? uni
          location = university_centers[ind]
        end
      end
      if location && (location.include? "MA, USA")
        location.sub! "MA, USA", "Massachusetts"
      end

      results = Geocoder.search(location)
      if !results.first.nil?
        coord = results.first.coordinates
        puts coord
        returned = where("acos(sin(homes.latitude * 0.0175) * sin(? * 0.0175)
                   + cos(homes.latitude * 0.0175) * cos(? * 0.0175) *
                     cos((? * 0.0175) - (homes.longitude * 0.0175))
                  ) * 3959 < ?", coord[0], coord[0], coord[1], 1)
      else
        returned = []
      end
      returned
    end
  }

  scope :with_coordination, lambda { |mapBounds|
    if !mapBounds.nil?
      map_bounds = JSON.parse(mapBounds)
      top_lat = map_bounds["nw"]["lat"]
      top_long = map_bounds["nw"]["lng"]
      bot_lat = map_bounds["se"]["lat"]
      bot_long = map_bounds["se"]["lng"]
      cent = map_bounds["center"]
      @@coords = [cent["lat"], cent["lng"]]
      if cent.nil? || cent.empty? || top_lat.nil?
        return all
      else
        returned = where("? < homes.latitude AND homes.latitude < ? AND ? < homes.longitude AND homes.longitude < ?",
                         bot_lat, top_lat, top_long, bot_long)
        returned
      end
    else
      return all
    end
  }

  def self.sorted_on_map(mapBounds, homes, bounds_sent)
    map_bounds = bounds_sent ? mapBounds.as_json : mapBounds.to_json
    map_bounds = JSON.parse(map_bounds)
    top_lat = map_bounds["nw"]["lat"]
    top_long = map_bounds["nw"]["lng"]
    bot_lat = map_bounds["se"]["lat"]
    bot_long = map_bounds["se"]["lng"]
    homes.order(Arel.sql("abs(homes.latitude - #{(top_lat + bot_lat)/2}) + abs(homes.longitude - #{(top_long + bot_long)/2})"))

  end

  scope :with_location_main_new, lambda { |location|
    if location.nil? || location.empty?
      return all
    else
      if location && (location.include? "MA, USA")
        location.sub! "MA, USA", "Massachusetts"
      end
      location = location.downcase.split.map(&:capitalize).join(' ')
      universities = ENV["UNIVERSITIES"].split(", ")
      university_centers = ENV["UNIVERSITY_CENTERS"].split(" | ")
      universities.each_with_index do |uni, ind|
        if location.include? uni
          location = university_centers[ind]
        end
      end
      @@coords = Rails.cache.fetch("#{location.to_s}-coordinates") do
         results = Geocoder.search(location)
         coordinates = results.first ? results.first.coordinates : [42.34192947980721, -71.0477805120952]
         coordinates
      end
      if @@coords.empty?
        properties = Home.none
        bounds = []
      else
        #properties = Rails.cache.fetch("#{location.to_s}-properties") do
          properties = []
=begin
          ENV["NEIGHBORHOOD_LIST"].split(", ").each do |neigh|
            if(location.include? neigh)
              properties = Home.where("city = ? OR neighborhood = ?", neigh, neigh)
              break
            end
          end
=end
          neighborhoods = Rails.cache.fetch("neighborhoods") do
             (Home.all.pluck(:neighborhood) + Home.all.pluck(:city)).uniq
          end

          neighborhood_search = neighborhoods.include?(location.split(",")[0])
          if properties.empty?
            if location == "Boston, MA, USA"
              properties = Home.where(state: "MA")
            elsif location.split(",")[0] != "Downtown" &&
               location.split(",")[0] != "Financial District" &&
               location.split(",")[0] != "Chinatown" && neighborhood_search
              properties = Home.where("homes.city = ? OR homes.neighborhood = ?", location.split(",")[0], location.split(",")[0])
            else
              properties = where("acos(sin(homes.latitude * 0.0175) * sin(? * 0.0175)
                       + cos(homes.latitude * 0.0175) * cos(? * 0.0175) *
                         cos((? * 0.0175) - (homes.longitude * 0.0175))
                      ) * 3959 < ?", @@coords[0], @@coords[0], @@coords[1], 1.5)
            end
          end
          properties = properties.where(status: "active")

        #end

        bounds = []
        #bounds = Rails.cache.fetch("#{location.to_s}-bounds") d0
          lats = properties.pluck(:latitude)
          lngs = properties.pluck(:longitude)
          min_lat = lats.min.to_f - 0.03
          max_lat = lats.max.to_f + 0.03
          min_lng = lngs.min.to_f - 0.03
          max_lng = lngs.max.to_f + 0.03
          avg_lat = lats.empty? || !neighborhood_search ? @@coords[0] : lats&.mean
          avg_lng = lngs.empty? || !neighborhood_search ? @@coords[1] : lngs&.mean
          bounds = {"center":{"lat":avg_lat,"lng":avg_lng},"nw":{"lat":max_lat,"lng":min_lng},"se":{"lat": min_lat ,"lng": max_lng},"sw":{"lat":min_lat,"lng":min_lng},"ne":{"lat":max_lat,"lng":max_lng}}
        #end


      end
      return [[avg_lat, avg_lng], properties, bounds]
    end
  }

  scope :with_location_main, lambda { |location|
    if location.nil? || location.empty?
      return all
    else
      universities = ENV["UNIVERSITIES"].split(", ")
      university_centers = ENV["UNIVERSITY_CENTERS"].split(" | ")
      universities.each_with_index do |uni, ind|
        if location.include? uni
          location = university_centers[ind]
        end
      end
      if location && (location.include? "MA, USA")
        location.sub! "MA, USA", "Massachusetts"
      end
      results = Geocoder.search(location)
      if !results.first.nil?
        coord = results.first.coordinates
        puts coord
        returned = where("acos(sin(homes.latitude * 0.0175) * sin(? * 0.0175)
                   + cos(homes.latitude * 0.0175) * cos(? * 0.0175) *
                     cos((? * 0.0175) - (homes.longitude * 0.0175))
                  ) * 3959 < ?", coord[0], coord[0], coord[1], 1)
      else
        returned = Home.none
      end
      [returned, coord]
    end
  }

  scope :with_fee_type, lambda { |scope_attrs|
    if scope_attrs == "All"
      return all
    elsif scope_attrs == "No broker fee"
      return where("client_fee = 0")
    elsif scope_attrs == "Reduced broker fee"
      return where("client_fee > 0")
    end

    return all
  }


  scope :with_cats_allowed, lambda { |allowed|
    if allowed.to_i == 1
      return joins(:building).where( "'Cats' = ANY(buildings.allowed_pets)")
    end
    return all
  }

  scope :with_dogs_allowed, lambda { |allowed|
    if allowed.to_i == 1
      return joins(:building).where( "'Small dogs' = ANY(buildings.allowed_pets) OR 'Big dogs' = ANY(buildings.allowed_pets)")
    end
    return all
  }

  scope :with_pets_allowed, lambda { |allowed|
    if allowed == 1
      return joins(:buildings).where( "'Pet-friendly' = ANY(buildings.allowed_pets)")
    end
    return all
  }

  scope :with_subletters_allowed, lambda { |allowed|
    if allowed == 1
      return where(sublet_allowed: true)
    end
    return all
  }

  scope :with_in_unit_laundry, lambda { |in_unit|
    if in_unit == 1
      return where(laundry: "In-unit")
    end
    return all
  }

  scope :with_central_ac, lambda { |central|
    if central == 1
      return where(ac: "Central")
    end
    return all
  }

  scope :with_available_rooms_range, lambda { |av|
    if av.min == "All"
      @@room_number = 1
      return all
    elsif av.min == "Studio"
      return where(property_type: "Studio")
    elsif av.min == "1" || av.min == 1
      return where(available_rooms: 1).where("property_type LIKE ? OR property_type = ?", "%Apartment%", "Split apartment")
    else
      @@room_number = av.min.to_i
      where("(rooms_individually_rented = ? AND available_rooms > ?) OR (available_rooms = ?) OR (property_type = ? AND available_rooms = ?)", true, av.min.to_i, av.min.to_i, "Split apartment", av.min.to_i - 1)
    end
  }

  scope :with_split_apartment, lambda { |split|
    if split == 0
      return where.not(property_type: "Split apartment")
    end
    return all
  }

  scope :with_apartment, lambda { |apt|
    if apt == 0
      return where.not(property_type: "Apartment")
    end
    return all
  }

  scope :with_studio, lambda { |studio|
    if studio == 0
      return where.not(property_type: "Studio")
    end
    return all
  }

  scope :with_room_for_rent, lambda { |room|
    if room == 0
      return where.not(property_type: "Room for rent")
    end
    return all
  }


  scope :with_availability_range, lambda { |date_range_attrs|
    start_date = Date.strptime(date_range_attrs.dates.split(" - ")[0], "%m/%d/%Y") rescue nil
    end_date = Date.strptime(date_range_attrs.dates.split(" - ")[1], "%m/%d/%Y") rescue nil
    puts start_date
    if !start_date && !end_date
      return all
    elsif !start_date
      return where("end_date >= ? AND end_date <= ?", end_date, end_date + 30.days)
    elsif !end_date
      return where("start_date <= ? AND start_date >= ?", start_date + 30.days, start_date - 30.days)
    end
    return where("start_date >= ? AND end_date <= ?", start_date, end_date)
  }

  #Since homes can have many rooms of different prices, we need the room number available in the price filter
  scope :with_price_range, lambda { |attrs|
    if attrs.min.is_a?(String) && attrs.max.is_a?(String)
      attrs.min = attrs.min.gsub("$", "").to_i
      attrs.max = attrs.max.gsub("$", "").to_i
    else
      attrs.min = attrs.min.to_i
      attrs.max = attrs.max.to_i
    end

    if attrs.min&.zero? && attrs.max&.zero?
      return all
    end

   where("price <= ? AND price >= ?", attrs.max, attrs.min)
  }

  scope :with_available_rooms_range_main, lambda { |num|
    if num == "All"
      @@room_number = 1
      return all
    else
      @@room_number = num
      where("(rooms_individually_rented = ? AND available_rooms > ?) OR (available_rooms = ?)", true, num.to_i, num.to_i)
    end
  }

  scope :with_total_bathrooms_range, lambda { |attrs|
    if attrs.min == "1"
      @@bath_room_number = 1
      return all
    else
      @@bath_room_number = attrs.min
      where("(total_bathrooms > ?) OR (total_bathrooms = ?)", attrs.min.to_i, attrs.min.to_i)
    end
  }

  scope :with_total_rooms_range, lambda { |attrs|
    if attrs.min == "Studio"
      where(property_type: "Studio")
    elsif attrs.min == "Studio+"
      return all
    elsif attrs.min.include? "+"
      where("total_rooms >= ?", attrs.min.to_i)
    elsif !attrs.min.include? "All"
      where("total_rooms = ?", attrs.min.to_i)
    else
      return all
    end
  }

  scope :with_furnished, lambda { |furnished|
    where(furnished: furnished)
  }

  scope :with_active, lambda { |is_active|
    if is_active
      where(status: 'active')
    else
      all
    end
  }

  scope :with_neighborhoods, lambda { |location_attrs|
    locations = location_attrs || []
    if locations.blank?
      return all
    else
      cwn = Home::cities_with_neighborhoods
      all_locations = locations&.map(&:downcase)
      cwn.slice(*locations).each do |k, v|
        all_locations << v
      end

      locations = all_locations&.flatten&.compact&.map(&:downcase)&.uniq || []
      returned = where("LOWER(homes.neighborhood) IN (?)", locations)
      returned
    end
  }

  scope :with_subway_lines, lambda { |subway_lines|
    subway_lines = subway_lines.map(&:downcase)
    return joins(building: [nearest_subway_stations: :subway_lines]).where("LOWER(subway_lines.name) IN (?)", subway_lines).group("homes.id")
  }

  def self.to_csv
    CSV.generate(headers: true) do |csv|
      csv << column_names + Option.column_names
      all.each do |home|
        if home.option
          csv << column_names.map { |attr| home.send(attr) || "nil" } + Option.column_names.map { |attr| home.option.send(attr) || "nil" }
        else
          csv << column_names.map { |attr| home.send(attr) || "nil" }
        end
      end
    end
  end

  def send_application_form(user, home_file)

    # send email and in app notification
    HomeApplicationMailer.home_application(self, home_file, user).deliver_now
    #push_notification(user, suggester, "sent you a group invite", group)

    #self.update(approved: true)
  end

  def set_hash_id
    hash_id = nil
    loop do
      hash_id = SecureRandom.urlsafe_base64(9).gsub(/-|_/, ("a".."z").to_a[rand(26)])
      break unless self.class.name.constantize.where(:hash_id => hash_id).exists?
    end
    self.hash_id = hash_id
  end

  def self.cache_key(home)
    if Rails.env.test?
      Rails.cache.clear
    end
    {
      serializer: "home",
      stat_record: home.updated_at,
    }
  end

  def self.send_approval_reminder
    homes = Home.where(status: "landlord_confirm", landlord_id: nil)
    homes = homes.where("created_at < ?", 1.week.ago)

    if Time.now.strftime("%A") != "Monday"
      return false
    end

    homes.each do |home|
      LandlordConfirmMailer.notify_landlord(home.user, home, nil, home.landlord_email).deliver_now
    end
    puts "finished sending emails"
  end

  def full_address
    f_address = address

    if apartment_number.present?
      address_split = address.split(/,(.+)/)
      f_address = "#{address_split[0]}, Apt #{apartment_number},#{address_split[1]}"
    end

    f_address
  end

  def calculated_score
    percent = 0

    if photos.length >= 10
      percent = 20
    else
      percent = photos.length * 2
    end

    if video_url.present? || virtual_tour_url.present?
      percent = percent + 10
    end

    if description.present?
      if description.length >= 500
        percent = percent + 25
      else
        percent = percent + (description.length/20)
      end
    end

    if self.building&.allowed_pets.present?
      percent = percent + 5
    end

    if neighborhood.present?
      percent = percent + 5
    end

    questions = self.property_questions
    if questions.first&.present? && questions.first&.question_text&.present?
      percent = percent + 10
    end

    if questions.second&.present? && questions.second&.question_text&.present?
      percent = percent + 10
    end

    if questions.third&.present? && questions.third&.question_text&.present?
      percent = percent + 5
    end

    mic_cols = %w[broker_fee mic_first_month mic_last_month mic_application_fee mic_move_in_fee mic_key_deposit mic_pet_deposit]
    this = self
    mic_cols_values = mic_cols.map { |mic_col| this.read_attribute(mic_col).present? }
    if mic_cols_values.all?
      percent = percent + 10
    else
      filled_cols_count = mic_cols_values.select{ |mic_col| mic_col }.length
      percent = percent + filled_cols_count
    end

    percent
  end

  def self.cities_with_neighborhoods
    cwn_result = Rails.cache.fetch("cities-with-neighborhoods", expires_in: 30.minutes) do
      cwn_hash = {}
      grouped_neighborhoods = Home.select("homes.city, ARRAY_AGG(DISTINCT homes.neighborhood) neighborhoods").group("homes.city").reject { |cwn| cwn.city.blank? || cwn.neighborhoods.blank? || cwn.city == "default" }

      grouped_neighborhoods.each do |each_grouped_neighborhood|
        cwn_hash[each_grouped_neighborhood.city] = each_grouped_neighborhood.neighborhoods.reject { |nbh| nbh == "default" }.uniq
      end

      cwn_hash
    end

    cwn_result
  end

  private

  def to_integer(data)
    begin
      value = data.split(" ")
      if data.include? "hour"
        value = value[0].to_i * 60 + value[2].to_i
      else
        value = value[0]
      end
      return value.to_i
    rescue
      return nil
    end
  end

  def updated_location(loc)
    if loc && (loc.include? "MA, USA")
      loc.sub! "MA, USA", "Massachusetts"
    end
    return loc
  end

  def need_poster_type
    if poster_type == ""
      errors.add(:poster_type, "Please choose poster type")
    end
  end

  def need_property_type
    if property_type == ""
      errors.add(:property_type, "Please choose property type")
    end
  end

  def pictures_for_each_room
    rooms.each do |r|
      if r.photos.count < 1
        errors.add(:rooms, "Please add at least 1 photo for each room")
      end
    end
  end

  #Checking if terms and conditions ic checked in the first step
  def has_to_agree
    if agreement != true
      errors.add(:agreement, "In order to post on the site you need to agree to this condition")
    end
  end
=begin
    def id_photo
      if !user.oauth_token && photos.select { |p| p.is_id == true }.count==0
        errors.add(:photos, "Has to have photo of id")
      end
    end
    def lease_photo
      if poster_type=="Tenant looking for roomates"&&photos.select { |p| p.is_lease == true }.count==0
        errors.add(:photos, "Has to have photo of lease")
      end
    end
=end

  def start_date_before_end_date
    return unless end_date && start_date
    if end_date < start_date
      errors.add(:end_date, "cannot be before Start date")
    end
  end

=begin
    def more_than_one_photo
      if !more_than_one_photo_cont
        errors.add(:photos, "Please upload the required number of photos")
      end
    end
=end

  #Checking if at least one checkbox is checked in both questions
=begin
    def amenities_two_valid
       if option
          if (option.heat == false && option.hot_water == false &&
            option.electricity == false && option.wireless == false && option.other_utilities == "")||
            (option.big_dogs == false && option.small_dogs == false &&
            option.cats == false && option.pet_friendly == false)
            errors.add(:option, "Please fill out required questions")
          end
       end
    end
=end
  #Checking if all 4 questions are answered
  def amenities_one_valid
    if heated.nil? || heated == "" || ac.nil? || ac == "" ||
       parking.nil? || parking == "" || laundry.nil? || laundry == ""
      errors.add(:home, "Please fill out required questions")
    end
  end

  def at_least_one_bedroom
    if self.new_record? || property_type == "Studio"
      return
    end
    rooms.each do |r|
      if r.room_type == nil or r.room_type == "bedroom"
        return true
      end
    end
    errors.add(:home, "Please add at least one bedroom")
  end

  #status of the home form checks

  def photos?
    status.to_s.include?("photos")
  end

  def active_or_photos?
    status.to_s.include?("anenities") || active?
  end

  def active_or_lease?
    status.to_s.include?("landlord-confirm") || active?
  end

  def active_or_rooms?
    status.to_s.include?("move-in-date-and-price") || active?
  end

  def active_or_house_info?
    status.to_s.include?("amenities") || active?
  end

  def active_or_rooms_and_total_rooms?
    (status.to_s.include?("amenities") || active?) && total_rooms
  end

  def active_or_amenities_one?
    status.to_s.include?("rules") || active?
  end

  def active_or_amenities_two?
    status.to_s.include?("amenities_2") || active?
  end

  def active?
    status == "active" || status == "inactive"
  end
end
