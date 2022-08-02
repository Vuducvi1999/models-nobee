class UserSignal < ApplicationRecord
  belongs_to :home
  belongs_to :user

  def self.clear_old_user_signals
    puts "Clearing old signals..."
    to_clear = UserSignal.where("created_at < ?", 3.days.ago)
    to_clear.each do |user_signal|
      user_signal.destroy
      puts "Deleted! #{user_signal.created_at}"
    end
    puts UserSignal.first.created_at
  end

  # comparator for user signals (active > nil) because sort_by does not works with nil
  # so a dummy user signal with type_signal = "no_signal" passed instead
  def <=>(other)
    if self.type_signal == "no_signal" && other.type_signal == "no_signal"
      return 0
    elsif other.type_signal == "no_signal"
      return 1
    else
      return -1
    end
  end
end
