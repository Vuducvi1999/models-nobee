class ShowingPayment < ApplicationRecord
  belongs_to :agent_info
  belongs_to :calendar_event

  enum status: { no_pay: 0, need_to_pay: 1, paid: 2 }
end
