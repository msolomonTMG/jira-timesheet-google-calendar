class CalendarController < ApplicationController
  def redirect
	google_api_client = Google::APIClient.new({
	  application_name: 'JIRA Timesheet Google Calendar',
	  application_version: '1.0.0'
	})

	google_api_client.authorization = Signet::OAuth2::Client.new({
	  client_id: ENV['GOOGLE_API_CLIENT_ID'],
	  client_secret: ENV['GOOGLE_API_CLIENT_SECRET'],
	  authorization_uri: 'https://accounts.google.com/o/oauth2/auth',
	  scope: 'https://www.googleapis.com/auth/calendar.readonly',
	  redirect_uri: 'https://glacial-plains-7554.herokuapp.com/callback',#url_for(:action => :callback)
	})

	authorization_uri = google_api_client.authorization.authorization_uri

	redirect_to authorization_uri.to_s
  end

  def callback
	google_api_client = Google::APIClient.new({
	  application_name: 'JIRA Timesheet Google Calendar',
	  application_version: '1.0.0'
	})

	google_api_client.authorization = Signet::OAuth2::Client.new({
	  client_id: ENV['GOOGLE_API_CLIENT_ID'],
	  client_secret: ENV['GOOGLE_API_CLIENT_SECRET'],
	  token_credential_uri: 'https://accounts.google.com/o/oauth2/token',
	  redirect_uri: 'https://glacial-plains-7554.herokuapp.com/callback',#url_for(:action => :callback),
	  code: params[:code]
	})

	response = google_api_client.authorization.fetch_access_token!

	session[:access_token] = response['access_token']

	redirect_to 'https://glacial-plains-7554.herokuapp.com/calendars'#url_for(:action => :calendars)
  end

  def calendars
	google_api_client = Google::APIClient.new({
	  application_name: 'JIRA Timesheet Google Calendar',
	  application_version: '1.0.0'
	})

	google_api_client.authorization = Signet::OAuth2::Client.new({
	  client_id: ENV['GOOGLE_API_CLIENT_ID'],
	  client_secret: ENV['GOOGLE_API_CLIENT_SECRET'],
	  access_token: session[:access_token]
	})

	google_calendar_api = google_api_client.discovered_api('calendar', 'v3')

	# response = google_api_client.execute({
	#   api_method: google_calendar_api.calendar_list.list,
	#   parameters: {}
	# })
	date = Date.today
	timezone = ActiveSupport::TimeZone['America/New_York']

	response = google_api_client.execute({
	  api_method: google_calendar_api.events.list,
	  parameters: {
	  	'calendarId' => 'primary',
	  	'timeMin' => '2015-10-14T10:00:00Z',#timezone.local(date.year, date.month, date.day),
	  	'timeMax' => '2015-10-15T10:00:00Z'#Time.now.to_datetime.rfc3339
	  }
	})

	meetings = response.data['items']
	@meetings_attended = Array.new

	meetings.each do |meeting|
		if meeting['status'] === "confirmed"
			@meetings_attended.push(meeting)
		end
	end
  end
end
