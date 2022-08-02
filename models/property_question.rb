class PropertyQuestion < ApplicationRecord
  has_paper_trail on: [:create, :destroy, :update]
  belongs_to :home
  belongs_to :user

  after_create :generate_timed_task

  def generate_timed_task
    ShowingTask.create!(
      deadline: nil,
      task_type: 'Q&A',
      task_source: 'automated',
      taskable_type: 'PropertyQuestion',
      taskable_id: self.id,
      name: "Answer question",
      instruction: "Please respond to this property question submitted by the user"
    )
  end
end
