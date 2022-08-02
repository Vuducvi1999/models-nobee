class Photo < ActiveRecord::Base
  belongs_to :room, optional: true
  belongs_to :home, touch: true, optional: true
  belongs_to :photoable, polymorphic: true, optional: true
  has_one_attached :image
    # :styles => { :medium => "300x200#", :large => "833x550#" },
    # :convert_options => { :medium => "-quality 50 -density 72", :large => "-quality 100 -density 72" }
  scope :with_eager_loaded_image, -> { eager_load(image_attachment: :blob) }
  validates :image, content_type: ['image/png', 'image/jpg', 'image/jpeg', 'image/heic']
  #validates :image, presence: true, blob: { content_type: ['image/png', 'image/jpg', 'image/jpeg']}
    #:path => ":rails_root/public/images/:id/:filename",
    #:url  => "/images/:id/:filename",

    #validates_attachment :image,:content_type => { :content_type => /\Aimage\/.*\Z/ }, size: { in: 0.megabytes..10.megabytes }

    def rotated_image
      if image.attached?
          image.variant(
            rotate: "#{rotation_angle.to_i}"
          )
      else
        "no_photo_user.png"
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
end
