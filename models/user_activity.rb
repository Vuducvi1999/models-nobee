class UserActivity < ApplicationRecord
  belongs_to :user
  before_save :keeping_platform_actived

  private

  def keeping_platform_actived
    if self.app_visited == false && self.app_visited_was == true
      self.app_visited = true
    end

    if self.web_visited == false && self.web_visited_was == true
      self.web_visited = true
    end
  end
end
