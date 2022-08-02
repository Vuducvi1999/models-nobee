class SubwayPlatform < ApplicationRecord
  belongs_to :subway_line
  belongs_to :subway_station
end
