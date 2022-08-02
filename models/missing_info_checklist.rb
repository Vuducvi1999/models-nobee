class MissingInfoChecklist < ApplicationRecord
  belongs_to :calendar_event
  belongs_to :agent, foreign_key: :agent_id, class_name: "User", optional: true
  has_paper_trail

  validates_exclusion_of :agent_ready, in: [true], message: "agent must assign if agent_ready checked", if: -> { self.agent_id == nil }
  before_save :update_agent_when_uncheck_agent_ready

  private

  def update_agent_when_uncheck_agent_ready
    if self.agent_ready_changed? && self.agent_ready == false
      self.agent_id = nil
    end
  end
end