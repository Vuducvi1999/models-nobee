class PersonalMessage < ApplicationRecord
  serialize :seen
  belongs_to :messageable, polymorphic: true, :touch => :messages_last_updated
  belongs_to :conversation, foreign_type: "Conversation", foreign_key: "messageable_id", optional: true, touch: true, polymorphic: true
  belongs_to :group_chat, foreign_type: "GroupChat", foreign_key: "messageable_id", optional: true, :touch => :messages_last_updated, polymorphic: true
  belongs_to :home, optional: true
  belongs_to :user
  has_one_attached :attachment
  validates :attachment, size: { less_than: 100.megabytes }
  has_paper_trail on: [:destroy]

  #after_commit :track_user_activity

  def self.convert_metadata_from_buildings_to_liveables(metadata_obj)
    if !metadata_obj.key?("buildings")
      return metadata_obj
    end

    new_metadata_obj = metadata_obj
    new_metadata_obj["liveables"] = metadata_obj["buildings"].map do |each_building|
      {
        "id": each_building["buildingSlug"],
        "type": each_building["buildingType"] == "multi-unit" ? "Building" : "Home"
      }
    end

    new_metadata_obj.except("buildings")
  end

  def self.convert_metadata_from_liveables_to_buildings(metadata_obj)
    if !metadata_obj.key?("liveables")
      return metadata_obj
    end

    new_metadata_obj = metadata_obj
    new_metadata_obj["buildings"] = metadata_obj["liveables"].map do |each_liveable|
      {
        "buildingSlug": each_liveable["id"],
        "buildingType": each_liveable["type"] == "Building" ? "multi-unit" : "single-unit"
      }
    end

    new_metadata_obj.except("liveables")
  end

  def track_user_activity
    admin_ids = User.where(account_type: "admin")
    if group_chat.group_chat_memberships.where(user_id: admin_ids).present?
      user.activities.create(
        title: "Sent a Nobee Message",
        content: body,
        activitable_id: self.id,
        activitable_type: "PersonalMessage"
      )
    end
  end
end
