class TimedTask < ApplicationRecord
  belongs_to :client, class_name: "User", foreign_key: "client_id"
  belongs_to :showing, class_name: "CalendarEvent", foreign_key: "showing_id", optional: true
  belongs_to :assignee, class_name: "User", foreign_key: "assignee_id", optional: true

  validates :title, presence: true
  validates :deadline, presence: true
  validates :title, uniqueness: { scope: [:client_id, :showing_id] }, if: -> { self.completed == false }
end
