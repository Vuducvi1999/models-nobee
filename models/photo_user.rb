class PhotoUser < ActiveRecord::Base
  default_scope {with_attached_image}
  belongs_to :user
  has_one_attached :image
  attr_accessor :crop_x, :crop_y, :crop_w, :crop_h
  scope :with_eager_loaded_image, -> { eager_load(image_attachment: :blob) }

  before_save :check_cropping

  def check_cropping
    self.crop_settings = {x: crop_x, y: crop_y, w: crop_w, h: crop_h} if cropping?
  end

  def cropping?
    !crop_x.blank? && !crop_y.blank? && !crop_w.blank? && !crop_h.blank?
  end

  def cropped?
    !self.crop_settings.nil? && !self.crop_settings["x"].blank? && !self.crop_settings["y"].blank? && !self.crop_settings["w"].blank? && !self.crop_settings["h"].blank?    
  end

  def cropped_image
    if image.attached?
      if crop_settings.is_a? Hash
        dimensions = "#{crop_settings['w']}x#{crop_settings['h']}"
        coord = "#{crop_settings['x']}+#{crop_settings['y']}"
        return image.variant(
          rotate: "#{rotation_angle.to_i}",
          crop: "#{dimensions}+#{coord}",
        )
      else
        image
      end
    else
      "no_photo_user.png"
    end
  end

  def resized_cropped_image(new_width, new_height)
    if image.attached?
      if crop_settings.is_a? Hash
        dimensions = "#{crop_settings['w']}x#{crop_settings['h']}"
        coord = "#{crop_settings['x']}+#{crop_settings['y']}"
        return image.variant(
          rotate: "#{rotation_angle.to_i}",
          crop: "#{dimensions}+#{coord}",
          resize: "#{new_width}x#{new_height}",
          quality: 10
        )
      else
        return image.variant(
          resize: "#{new_width}x#{new_height}",
          quality: 10
        )
      end
    end
  end

  def rotated
    if rotation_angle
      image.variant(
        rotate: "#{rotation_angle}"
      )
    else
      image
    end
  end

  #validates :image, presence: true, blob: { content_type: ['image/png', 'image/jpg', 'image/jpeg']}
    #:path => ":rails_root/public/user_images/:id/:filename",
    #:url  => "/user_images/:id/:filename",
    #:styles => { :medium => "300x200>", :large => "833x550" },
    #:convert_options => { :medium => "-quality 300 -density 72", :large => "-quality 300 -density 72" }
    #validates_attachment :image,:content_type => { :content_type => /\Aimage\/.*\Z/ }, size: { in: 0.megabytes..10.megabytes }
end
