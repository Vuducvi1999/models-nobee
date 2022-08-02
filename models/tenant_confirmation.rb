class TenantConfirmation < ApplicationRecord
  has_paper_trail on: [:create, :destroy, :update]
  enum status: { waiting: 0, confirmed: 1, rescheduled: 2 }

  belongs_to :calendar_event, optional: true
end
