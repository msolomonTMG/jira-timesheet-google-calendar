class ApplicationController < ActionController::Base
  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :exception

  rescue_from JIRA::OauthClient::UninitializedAccessTokenError do
    redirect_to 'https://glacial-plains-7554.herokuapp.com/jira-auth'
  end

  private

  def get_jira_client

    # add any extra configuration options for your instance of JIRA,
    # e.g. :use_ssl, :ssl_verify_mode, :context_path, :site
    options = {
      :private_key_file => "server.key",
      :consumer_key => ENV['CONSUMER_KEY'],
      :use_ssl => true,

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
end
