class NearestSubwayStationBuilding < ApplicationRecord
  belongs_to :building
  belongs_to :subway_station
end
