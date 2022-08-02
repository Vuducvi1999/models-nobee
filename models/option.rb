class Option < ApplicationRecord
  belongs_to :home, touch: true
end
