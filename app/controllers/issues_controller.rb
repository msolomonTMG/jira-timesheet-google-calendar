class IssuesController < ApplicationController
  #before_filter :get_jira_client
  def index
    @issues = @jira_client.Issue.all
  end

  def show
    @issue = @jira_client.Issue.find(params[:id])
  end

  def query
    access_token = @jira_client.access_token(
      session[:jira_auth][:access_token],
      session[:jira_auth][:access_key]
    )
  	#@issue = session
  	@issue = @jira_client.Issue.find('JQWE-1')

  end
end
