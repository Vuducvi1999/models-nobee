class SubwayLine < ApplicationRecord
  has_many :subway_platforms
  has_many :subway_stations, through: :subway_platforms
end
