require 'kimurai'
require 'date'

class Rockrose < Kimurai::Base
  @engine = :selenium_chrome
  @start_urls = ["https://rockrose.com/availabilities"]

  def parse(response, url:, data: {})
    unit_count = response.xpath("//ul[@id='availabilities-grid']/li").count
    unit_urls = []
    extra_infos = []
    items = []
    unit_count.times do |i|
      unit_url_path = "//ul[@id='availabilities-grid']/li[#{i+1}]/div/footer/a"
      unit_url = response.xpath(unit_url_path).at('a').get_attribute('href')
      unit_urls.append(unit_url)

      extra_info_path = "//ul[@id='availabilities-grid']/li[#{i+1}]/div/div/ul/li[3]"
      extra_info = response.xpath(extra_info_path).text.strip
      extra_infos.append(extra_info)

      price_path = "//ul[@id='availabilities-grid']/li[#{i+1}]/div/div/ul/li[1]"
      price = response.xpath(price_path).text.strip.sub('$', '').sub(',', '').to_f

      bed_bath_path = "//ul[@id='availabilities-grid']/li[#{i+1}]/div/div/ul/li[2]"
      bed_bath = response.xpath(bed_bath_path).text.strip.split(', ')
      bed = bed_bath[0].split(' ')
      if bed.include?("Studio")
        property_type = "Studio"
        bed_num = 1
      elsif bed.include?("Bedroom")
        property_type = "Apartment"
        bed_num = bed[0].to_f
      end
      bath = bed_bath[1].split(' ')
      bath_num = bath[0].to_f

      address_first_path = "//ul[@id='availabilities-grid']/li[#{i+1}]/div/div/div/span[1]/text()[1]"
      address_first = response.xpath(address_first_path).text.strip
      address_second_path = "//ul[@id='availabilities-grid']/li[#{i+1}]/div/div/div/span[1]/text()[2]"
      address_second = response.xpath(address_second_path).text.strip

      full_address = address_first + ' ' + address_second
      street = address_first.sub(',', '').sub(' ', ',').split(',')
      address_second_array = address_second.split(', ')
      state_zipcode = address_second_array[1].split(' ')
      street_name = street[1]
      street_number = street[0]
      city = address_second_array[0]
      state = state_zipcode[0]
      zipcode = state_zipcode[1]
      apartment_number_path = "//ul[@id='availabilities-grid']/li[#{i+1}]/div/div/div/span[2]"
      apartment_number = response.xpath(apartment_number_path).text.tr("#", "").strip
      address = address_first
      neighborhood_path = "//ul[@id='availabilities-grid']/li[#{i+1}]/div/div/div/span[3]"
      neighborhood = response.xpath(neighborhood_path).text.strip

      item = {}
      item[:street_number] = street_number
      item[:street_name] = street_name
      item[:city] = city
      item[:state] = state
      item[:zipcode] = zipcode
      item[:apartment_number] = apartment_number
      item[:neighborhood] = neighborhood
      item[:address] = address
      item[:full_address] = full_address.tr("-", "")
      item[:price] = price
      item[:property_type] = property_type
      item[:available_rooms] = bed_num
      item[:total_bathrooms] = bath_num

      items.append(item)
    end

    unit_count.times do |i|
      unit_url = unit_urls[i]
      browser.visit(unit_url)
      sleep 1
      response = browser.current_response
      item = items[i]

      image_urls = []
      image_path = "//div[@class='single-listing-tabs__slide_wrapper slick-slide slick-cloned']"
      image_rep = response.xpath(image_path)
      check_dup = 0
      image_rep.each do |rep|
        image_urls.append(rep.at("img").get_attribute("src")) unless check_dup == 0
        check_dup = check_dup + 1
      end
      item[:image_urls] = image_urls

      virtual_tour_path = "//iframe[@class='responsive-iframe']"
      virtual_tour_rep = response.xpath(virtual_tour_path)
      virtual_tour_url = nil
      virtual_tour_url = virtual_tour_rep.at("iframe").get_attribute("src") unless virtual_tour_rep.at("iframe").class == NilClass
      item[:virtual_tour_url] = virtual_tour_url

      building_description_path = "//div[@id='print-area']/section[2]/div/div/div[4]/p"
      building_description_rep = response.xpath(building_description_path)
      check_end = 1
      building_description = ""
      building_description_rep.each do |rep|
        building_description = building_description + rep.text.strip
        building_description = building_description + "\n" unless check_end == building_description_rep.count
        check_end = check_end + 1
      end
      item[:building_description] = building_description

      apartment_description_path = "//div[@id='print-area']/section[2]/div/div/div[1]/text()"
      apartment_description = ""
      apartment_description = response.xpath(apartment_description_path).text.strip
      item[:apartment_description] = apartment_description

      apartment_features_path = "//div[@id='print-area']/section[2]/div/div/div[2]/ul/li"
      apartment_features_rep = response.xpath(apartment_features_path)
      apartment_features = []
      apartment_features_rep.each do |rep|
        apartment_features.append(rep.text)
      end
      item[:apartment_features] = apartment_features

      apartment_amenities_path = "//div[@id='print-area']/section[2]/div/div/div[5]/ul/li"
      apartment_amenities_rep = response.xpath(apartment_amenities_path)
      apartment_amenities = []
      apartment_amenities_rep.each do |rep|
        apartment_amenities.append(rep.text)
      end

      available_date = Date.parse(DateTime.now.strftime("%d/%m/%Y"))
      item[:start_date] = available_date
      item[:included_amenities] = apartment_amenities
      item[:landlord_name] = "Rockrose"
      item[:heated] = "None"
      item[:ac] = "None"
      item[:laundry] = "None"
      item[:parking] = "None"
      item[:status] = 'inactive'
      item[:furnished] = 'false'

      begin
        results = Geocoder.search(item[:full_address])
        coords = results.first.coordinates
        item[:latitude] = coords[0]
        item[:longitude] = coords[1]
        full_address = results.first.formatted_address
        street_number = results.first.data["address_components"][0]["long_name"]
        street_name = results.first.data["address_components"][1]["long_name"]
        city = results.first.data["address_components"][3]["long_name"]
        state =  results.first.data["address_components"][5]["short_name"]
        zipcode = results.first.data["address_components"][7]["long_name"]
        found_building = Building.find_by(
          street_number: street_number,
          street_name: street_name,
          city: city,
          state: state,
          zipcode: zipcode
        )
        building_id = if found_building.present?
                        found_building.update(building_type: "multi-unit")
                        found_building.id
                      else
                        building_description = item[:building_description]
                        new_building = Building.create!(
                          landlord_id: 6,
                          landlord_email: "test@test4.com",
                          latitude: item[:latitude] ,
                          longitude: item[:longitude],
                          title: item[:full_address],
                          description: item[:building_description],
                          address: item[:full_address],
                          heated: item[:heated],
                          parking: item[:parking],
                          neighborhood: item[:neighborhood],
                          street_number: street_number,
                          street_name: street_name,
                          city: city,
                          state: state,
                          zipcode: zipcode,
                          building_type: "single-unit",
                          allowed_pets: []
                        )
                        new_building.id
                      end
        begin
          home = Home.find_by(address: item[:full_address], apartment_number: item[:apartment_number])
          if !home
            home = Home.create!(
              user_id: 6, notification_id: nil, ygl_id: nil,
              title: full_address, security_deposit: nil,
              promotion_type: 1,
              description: item[:apartment_description],
              landlord_name: item[:landlord_name],
              apartment_number: item[:apartment_number],
              property_type: item[:property_type],
              street_number: street_number,
              street_name: street_name,
              zipcode: zipcode,
              address: full_address,
              city: city,
              state: state,
              price: item[:price], start_date: item[:start_date],
              end_date: nil, capacity: item[:available_rooms],
              total_rooms: item[:available_rooms], available_rooms: item[:available_rooms],
              total_bathrooms: item[:total_bathrooms], private_bathrooms: 0, furnished: item[:furnished],
              latitude: item[:latitude], longitude: item[:longitude],
              entire_home: false,
              sublet_allowed: false, agreement: true,
              landlord_id: 6,
              heated: item[:heated], ac: item[:ac], laundry: item[:laundry], parking: item[:parking], status: item[:status],
              neighborhood: item[:neighborhood],

              # Move in costs
              mic_broker_fee: 0,
              mic_first_month: nil,
              mic_last_month: nil,
              mic_application_fee: nil,
              mic_move_in_fee: nil,
              mic_key_deposit: nil,
              mic_pet_deposit: nil,
              # amentities
              additional_amenities: [],
              included_amenities: item[:included_amenities],
              # building
              building_id: building_id,
              virtual_tour_url: item[:virtual_tour_url]
            )
            item[:image_urls].each do |image_url|
              url = image_url
              tempfile = Tempfile.new
              tempfile.binmode
              tempfile.write URI.open(url).read
              tempfile.rewind
              photo = Photo.create(home_id: home.id, photoable_id: home.id, photoable_type: "Home")
              photo.image.attach(io:tempfile, filename: url.split("/").last)
            end
          else

            home.update(price: item[:price], start_date: item[:start_date], virtual_tour_url: item[:virtual_tour_url])
          end
        end
        owner = Owner.find_by_name(item[:landlord_name])
        if owner.nil?
          owner = Owner.create(name: item[:landlord_name])
        end
        home.update(owner_id: owner.id)
      end
    end
  end
end
