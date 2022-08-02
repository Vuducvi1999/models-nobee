class Room < ApplicationRecord
  include Comparable

  belongs_to :home
  has_one :furniture, :dependent => :destroy
  has_many :photos, :dependent => :destroy
  #has_many :showings, :dependent => :destroy
  has_many :calendar_events, :dependent => :destroy
  accepts_nested_attributes_for :photos
  accepts_nested_attributes_for :furniture
  #validates :footage, presence: true, numericality: true
  validate :valid_room, on: :update

  scope :with_type, -> (room_type) { where(room_type: room_type) }

  # compare two rooms based on room type and room index
  def <=>(other)
    if self.nil? && other.nil?
      return 0
    elsif self.nil?
      return 1
    elsif other.nil?
      return -1
    end

    priorities = {"bedroom" => 0, "living_room" => 1, "kitchen" => 2, "bathroom" => 3, "half_bathroom" => 4, "dummy_room" => 5}

    if priorities[self.room_type] > priorities[other.room_type]
      1
    elsif priorities[self.room_type] < priorities[other.room_type]
      -1
    else
      if self.room_index.nil?
        1
      elsif other.room_index.nil?
        -1
      else
        self.room_index <=> other.room_index
      end
    end
  end

  def valid_room
      if room_type == "bedroom" && !price
        puts id
        puts room_type
        errors.add(:rooms, "Please enter price for each bedroom")
      end
  end

end
