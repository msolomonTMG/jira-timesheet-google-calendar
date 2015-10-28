class ApplicationController < ActionController::Base
  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :exception

  rescue_from JIRA::OauthClient::UninitializedAccessTokenError do
    redirect_to '/jira-auth'
  end

  private

  def get_jira_client
    # add any extra configuration options for your instance of JIRA,
    # e.g. :use_ssl, :ssl_verify_mode, :context_path, :site
    options = {
      :private_key_file => "rsakey.pem",
      :consumer_key => ENV['JIRA_CONSUMER_KEY'],
      :site => "https://thrillistmediagroup.atlassian.net",
      :context_path => ""
    }

    @jira_client = JIRA::Client.new(options)

    # Add AccessToken if authorised previously.
    if session[:jira_auth]
      @jira_client.set_access_token(
        session[:jira_auth][:access_token],
        session[:jira_auth][:access_key]
      )
    end
  end

  def get_google_api
    google_api_client = Google::APIClient.new({
      application_name: 'JIRA Timesheet Google Calendar',
      application_version: '1.0.0'
    })

    google_api_client.authorization = Signet::OAuth2::Client.new({
      client_id: ENV['GOOGLE_API_CLIENT_ID'],
      client_secret: ENV['GOOGLE_API_CLIENT_SECRET'],
      authorization_uri: 'https://accounts.google.com/o/oauth2/auth',
      scope: 'https://www.googleapis.com/auth/calendar.readonly',
      redirect_uri: 'http://localhost:5000/callback'#'https://glacial-plains-7554.herokuapp.com/callback',#url_for(:action => :callback)
    })

    authorization_uri = google_api_client.authorization.authorization_uri

    redirect_to authorization_uri.to_s
  end

end
