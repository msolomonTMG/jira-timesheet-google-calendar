class IssuesController < ApplicationController
  before_filter :get_jira_client
  def index
    @issues = @jira_client.Issue.all
  end

  def show
    @issue = @jira_client.Issue.find(params[:id])
  end
end
