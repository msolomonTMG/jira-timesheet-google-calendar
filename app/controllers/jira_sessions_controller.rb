class JiraSessionsController < ApplicationController
  before_filter :get_jira_client

  def new
    callback_url = 'http://localhost:5000/jira-callback'
    request_token = @jira_client.request_token(oauth_callback: callback_url)
    session[:request_token] = request_token.token
    session[:request_secret] = request_token.secret

    redirect_to request_token.authorize_url
  end

  def authorize
    request_token = @jira_client.set_request_token(
      session[:request_token], session[:request_secret]
    )
    access_token = @jira_client.init_access_token(
      :oauth_verifier => params[:oauth_verifier]
    )

    session[:jira_auth] = {
      :access_token => access_token.token,
      :access_key => access_token.secret
    }

    session.delete(:request_token)
    session.delete(:request_secret)

    redirect_to '/query'
  end

  def destroy
    session.data.delete(:jira_auth)
  end

  def log_time
    @meetings = Array.new
    @responses = Array.new

    params.each do |meeting|
      if meeting[0].is_number? && meeting[1]['check'] === "on"
        @meetings.push(meeting)
      end
    end

    @meetings.each do |meeting|
      url = "#{ENV['JIRA_URL']}/rest/api/2/issue/THR-1121/worklog"
      data = {
        :timeSpent => meeting[1]['time'],
        :comment  => meeting[1]['summary']
      }.to_json
      headers = {
       :Authorization => 'Basic bXNvbG9tb246IVluZnRwbzEy',
       :content_type  => 'application/json'
      }
      response = RestClient.post url, data, headers
      @responses.push(response)
    end

  end

end
