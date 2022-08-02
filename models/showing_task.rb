class ShowingTask < ApplicationRecord
  has_paper_trail on: [:create, :destroy, :update]
  belongs_to :calendar_event, optional: true
  belongs_to :taskable, polymorphic: true, optional: true
  validates :name, presence: true

  def self.create_by_blueprint(id, blueprint, showing)
    JSON.parse(blueprint).map do |task| 
      self.create(
        {
          "deadline": showing.start_datetime - task["time_before"]&.to_i&.hours,
          "name": task["name"],
          "instruction": task["instruction"],
          "taskable_type": "CalendarEvent",
          "task_source": "automated",
          "taskable_id": id,
          "task_type": "showing"
        }
      ) 
    end
  end
end
