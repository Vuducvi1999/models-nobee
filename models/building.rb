class Building < ApplicationRecord
  has_paper_trail on: [:create, :destroy, :update]
  validates :latitude, presence: true, numericality: true
  validates :longitude, presence: true, numericality: true
  validates :address, presence: true
  # validates :neighborhood, presence: true
  # validates :street_number, presence: true
  # validates :street_name, presence: true
  # validates :city, presence: true
  # validates :state, presence: true
  # validates :zipcode, presence: true
  validates :building_type, presence: true

  has_many :units, class_name: "Home"
  has_many :photos, -> { where(photoable_type: "Building").order(position: :asc)}, foreign_key: "photoable_id"
  has_many :unit_photos, -> { where('homes.status' => "active")},through: :units, source: :photos
  belongs_to :landlord, class_name: "User", optional: true
  has_many :nearest_subway_station_buildings
  has_many :nearest_subway_stations, through: :nearest_subway_station_buildings, source: :subway_station

  before_validation :generate_slug, on: :create
  after_commit :update_nearest_subway_stations, on: [:create, :update], if: -> { ["latitude", "longitude"] & self.previous_changes.keys != [] && self.state.downcase == 'ma' }

  @@coords = []

  def get_price_range
    prices = units.pluck(:price)
    [prices.min, prices.max]
  end

  def self.find_coordinates_by_location(location)
    results = Geocoder.search(location)

    return [] if results.first.blank?

    results.first.coordinates
  end

  def self.filter_with_location(location)
    if location.blank?
      return [], all, []
    end

    location.sub!("MA, USA", "Massachusetts") if location.present? && location.include?("MA, USA")
    location = location.downcase.split.map(&:capitalize).join(' ')
    universities = ENV["UNIVERSITIES"].split(", ")
    university_centers = ENV["UNIVERSITY_CENTERS"].split(" | ")
    universities.each_with_index do |uni, ind|
      if location.include? uni
        location = university_centers[ind]
      end
    end

    coordinates = Rails.cache.fetch("#{location.to_s}-coordinates") do
      results = Geocoder.search(location)
      coordinates = results.first ? results.first.coordinates : []
    end

    if coordinates.empty?
      buildings = Building.none
      bounds = []
    else
      buildings = []

      if buildings.empty?
        buildings = Building.where(
          """acos(sin(buildings.latitude * 0.0175) * sin(? * 0.0175)
          + cos(buildings.latitude * 0.0175) * cos(? * 0.0175) *
          cos((? * 0.0175) - (buildings.longitude * 0.0175))
          ) * 3959 < ?""",
          coordinates[0],
          coordinates[0],
          coordinates[1],
          1.5
        )
      end

      buildings = buildings
      bounds = []
      lats = buildings.pluck(:latitude)
      lngs = buildings.pluck(:longitude)
      min_lat = lats.min.to_f - 0.03
      max_lat = lats.max.to_f + 0.03
      min_lng = lngs.min.to_f - 0.03
      max_lng = lngs.max.to_f + 0.03
      bounds = {
        "center": {
          "lat": coordinates[0],
          "lng": coordinates[1]
        },
        "nw": {
          "lat": max_lat,
          "lng": min_lng
        },
        "se": {
          "lat": min_lat,
          "lng": max_lng
        },
        "sw":{
          "lat": min_lat,
          "lng": min_lng
        },
        "ne": {
          "lat": max_lat,
          "lng": max_lng
        }
      }
    end

    return [coordinates, buildings, bounds]
  end

  def self.filter_with_map_bounds(map_bounds_param)
    if map_bounds_param.present?
      map_bounds = JSON.parse(map_bounds_param)
      top_lat = map_bounds["nw"]["lat"]
      top_long = map_bounds["nw"]["lng"]
      bot_lat = map_bounds["se"]["lat"]
      bot_long = map_bounds["se"]["lng"]
      cent = map_bounds["center"]
      @@coords = [cent["lat"], cent["lng"]]
      if cent.nil? || cent.empty? || top_lat.nil?
        return all
      else
        return where("? < buildings.latitude AND buildings.latitude < ? AND ? < buildings.longitude AND buildings.longitude < ?", bot_lat, top_lat, top_long, bot_long)
      end
    end

    all
  end

  def self.set_coords(coords)
    @@coords = coords
  end

  def calculated_score
    percent = 0

    if photos.length >= 5
      percent = 10
    else
      percent = photos.length * 2
    end

    if description.present?
      if description.length >= 600
        percent = percent + 30
      else
        percent = percent + (description.length/20)
      end
    end

    if neighborhood.present?
      percent = percent + 5
    end

    questions = PropertyQuestion.joins(home: [:building]).where("buildings.id = ?", id)
    if questions.where.not(answered_at: nil).length == questions.length
      percent = percent + 20
    end

    unit_scores = Home.where(building_id: 1).pluck(:score).compact
    average = unit_scores.sum / unit_scores.size.to_f
    percent = percent + average/100*30

    percent
  end

  filterrific(
    default_filter_params: { },
    available_filters: [
      :with_availability_range,
      :with_total_rooms_range,
      :with_available_rooms_range,
      :with_total_bathrooms_range,
      :with_price_range,
      :with_dogs_allowed,
      :with_cats_allowed,
      :with_fee_type,
      :sorted_by
    ]
  )

  # Filterrific scopes
  scope :with_availability_range, lambda { |scope_attrs|
    start_date, end_date = scope_attrs[:dates].split(" - ")
    start_date = Date.strptime(start_date, "%m/%d/%Y") rescue nil
    end_date = Date.strptime(end_date, "%m/%d/%Y") rescue nil

    if !start_date && !end_date
      return all
    elsif !start_date
      return where("homes.end_date >= ? AND homes.end_date <= ?", end_date, end_date + 30.days)
    elsif !end_date
      return where("homes.start_date <= ? AND homes.start_date >= ?", start_date + 3.days, start_date - 30.days)
    end

    where("homes.start_date >= ? AND homes.end_date <= ?", start_date, end_date)
  }

  scope :with_total_rooms_range, lambda { |scope_attrs|
    if scope_attrs[:min] == "1+"
      total_room_number = 1
      return all
    end

    total_room_number = scope_attrs[:min].to_i
    where("homes.total_rooms > ? OR homes.total_rooms = ?", total_room_number, total_room_number)
  }

  scope :with_available_rooms_range, lambda { |scope_attrs|
    if scope_attrs[:min] == "All"
      room_number = 1
      return all
    end

    room_number = scope_attrs[:min].to_i
    where(
      "(homes.rooms_individually_rented = ? AND homes.available_rooms > ?) OR (homes.available_rooms = ?) OR (homes.property_type = ? AND homes.available_rooms = ?)",
      true,
      room_number,
      room_number,
      "Split apartment",
      room_number - 1
    )
  }

  scope :with_total_bathrooms_range, lambda { |scope_attrs|
    if scope_attrs[:min] == "1+"
      bath_room_number = 1
      return all
    end

    bath_room_number = scope_attrs[:min].to_i
    where("(homes.total_bathrooms > ?) OR (homes.total_bathrooms = ?)", bath_room_number, bath_room_number)
  }

  scope :with_price_range, lambda { |scope_attrs|
    if scope_attrs[:min].is_a?(String) && scope_attrs.max.is_a?(String)
      scope_attrs[:min] = scope_attrs[:min].gsub("$", "").to_i
      scope_attrs[:max] = scope_attrs[:max].gsub("$", "").to_i
    else
      scope_attrs[:min] = scope_attrs[:min].to_i
      scope_attrs[:max] = scope_attrs[:max].to_i
    end

    if scope_attrs[:min]&.zero? && scope_attrs[:max]&.zero?
      return all
    end

    where("homes.price <= ? AND homes.price >= ?", scope_attrs[:max], scope_attrs[:min])
  }

  scope :with_fee_type, lambda { |scope_attrs|
    if scope_attrs == "All"
      return all
    elsif scope_attrs == "No broker fee"
      return where("homes.client_fee = 0")
    elsif scope_attrs == "Reduced broker fee"
      return where("homes.client_fee > 0")
    end

    return all
  }

  scope :with_dogs_allowed, lambda { |scope_attrs|
    if scope_attrs.to_i == 1
      return where("'Small dogs' = ANY(buildings.allowed_pets) OR 'Big dogs' = ANY(buildings.allowed_pets)")
    end

    all
  }

  scope :with_cats_allowed, lambda { |scope_attrs|
    if scope_attrs.to_i == 1
      return where("'Cats' = ANY(buildings.allowed_pets)")
    end

    all
  }

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
      order(Arel.sql("abs(buildings.latitude - #{@@coords[0]}) + abs(buildings.longitude - #{@@coords[1]})"))
    else
      raise(ArgumentError, "Invalid sort option: #{sort_key.inspect}")
    end
  }

  private

  def generate_slug
    if self.neighborhood && self.city && self.neighborhood != self.city
      self.slug = (address.to_s + ", " + neighborhood.to_s)&.parameterize
    else
      self.slug = address&.parameterize
    end
  end

  def update_nearest_subway_stations
    # getting the nearest subway station ids
    service = GoogleDistanceMatrixService.new(mode: 'walking', google_api_key: ENV["GOOGLE_KEY"])
    subway_station_coordinates = SubwayStation.all.pluck(:id, :latitude, :longitude)
    expected_walking_time = 15*60 # 15 minutes

    expected_station_ids = service.get_nearest_subway_station_ids_of_building(building, subway_station_coordinates, expected_walking_time)
      
    building.nearest_subway_station_ids = expected_station_ids
    building.nearby_subway_lines = SubwayLine.joins(:subway_stations).where(subway_stations: {id: expected_station_ids}).uniq.pluck(:name).uniq
    building.save(validate: false)
  end
end
