class Furniture < ApplicationRecord
  belongs_to :room

  # the dictionary with key as furniture string and value as furniture image url
  @@dict_furniture_img_url = {}
  @@dict_furniture_img_url[:sofa] = 'https://img.icons8.com/material-rounded/30/000000/sofa.png'
  @@dict_furniture_img_url[:coffee_table] = 'https://img.icons8.com/metro/30/000000/table.png'
  @@dict_furniture_img_url[:tv] = 'https://img.icons8.com/ios-glyphs/30/000000/tv.png'
  @@dict_furniture_img_url[:tv_stand] = 'https://img.icons8.com/ios-glyphs/30/000000/table.png'
  @@dict_furniture_img_url[:nightstand] = 'https://img.icons8.com/metro/30/000000/table.png'
  @@dict_furniture_img_url[:closet] = 'https://img.icons8.com/ios-filled/30/000000/closet.png'
  @@dict_furniture_img_url[:shoeshelf] = 'https://img.icons8.com/ios-filled/30/000000/buffet.png'
  @@dict_furniture_img_url[:lamp] = 'https://img.icons8.com/metro/30/000000/desk-lamp.png'
  @@dict_furniture_img_url[:curtain] = 'https://img.icons8.com/material/30/000000/blind-up.png'
  @@dict_furniture_img_url[:bed] = 'https://img.icons8.com/material/30/000000/bed.png'
  @@dict_furniture_img_url[:desk] = 'https://img.icons8.com/material/30/000000/desk.png'
  @@dict_furniture_img_url[:chair] ='https://img.icons8.com/windows/30/000000/chair.png'

  def get_furnitures_in_living_room
    return [:sofa, :coffee_table, :tv, :tv_stand, :nightstand, :closet, :shoeshelf, :lamp, :curtain]
  end

  def get_furnitures_in_bedroom
    return [:bed, :desk, :chair, :nightstand, :closet, :lamp, :curtain]
  end

  def get_furnitures_in_specified_bedroom(room_id)
    furnitures = []
    room_furnitures = []
    @room = Room.find(room_id)
    if !@room.room_type || @room.room_type == 'bedroom'
      room_furnitures = @room.furniture.get_furnitures_in_bedroom()
    end
    if @room.room_type == 'living_room'
      room_furnitures = @room.furniture.get_furnitures_in_living_room()
    end

    for attr in room_furnitures
      if @room.furniture[attr]
        furnitures.push(attr)
      end
    end
    return furnitures
  end

  def get_furniture_img_url(furniture)
    return @@dict_furniture_img_url[furniture.to_sym]
  end
end
