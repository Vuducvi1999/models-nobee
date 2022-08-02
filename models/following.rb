class Following < ApplicationRecord
  belongs_to :user, touch: true
  belongs_to :home, touch: true, optional: true
  belongs_to :building, touch: true, optional: true

  validate :user_should_not_follow_their_own_homes
  validate :user_should_not_follow_their_own_buildings

  after_commit :follow_recommended_unit, on: :create
  after_destroy :unfollow_recommended_unit

  def user_should_not_follow_their_own_homes
    if user == home&.user
      errors.add(:user, "should not follow their own homes")
    end
  end

  def user_should_not_follow_their_own_buildings
    if user == building&.landlord
      errors.add(:user, "should not follow their own buildings")
    end
  end

  private

  def follow_recommended_unit
    if RecommendProperty.find_by(home_id: self.home_id, user_id: self.user_id).present?
      Activity.create!(
        user_id: self.user_id,
        title: "Client #{self.user.full_name} saved property that is recommended",
        content: "Property #{self.home.full_address}",
        activitable_id: self.id,
        activitable_type: "Following"
      )
    end
  end

  def unfollow_recommended_unit
    if RecommendProperty.find_by(home_id: self.home_id, user_id: self.user_id).present?
      Activity.create!(
        user_id: self.user_id,
        title: "Client #{self.user.full_name} unfollow property that is recommended",
        content: "Property #{self.home.full_address}",
        activitable_id: self.id,
        activitable_type: "Following"
      )
    end
  end
end
