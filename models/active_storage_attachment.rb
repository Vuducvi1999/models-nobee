# active_storage_attachment.rb
class ActiveStorageAttachment < ApplicationRecord
  has_one_attached :file
  delegate :filename, to: :file, allow_nil: true
end
