class SubwayStation < ApplicationRecord
  has_many :subway_platforms
  has_many :subway_lines, through: :subway_platforms
  has_many :nearest_subway_station_buildings
  has_many :nearest_buildings, through: :nearest_subway_station_buildings, source: :building
end
