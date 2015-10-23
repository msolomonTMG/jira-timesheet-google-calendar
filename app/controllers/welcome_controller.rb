class WelcomeController < ApplicationController

  # GET /welcome
  def index
  	now = Time.now
  	@today_9am = Time.new now.year, now.month, now.day, 9, 0, 0
  end

end
