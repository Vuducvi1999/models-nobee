class Note < ApplicationRecord
  belongs_to :user
  belongs_to :created_by, class_name: "User", optional: true

  validates :title, presence: true

  after_commit :track_user_activity

  def track_user_activity
    user.activities.create(
      title: "Nobee's admin wrote a new note",
      content: content,
      activitable_id: self.id,
      activitable_type: "Note"
    )
  end
end
