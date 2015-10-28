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

    #uncomment this and it works but the @jira_client variable does nothing outside of this action
    # @issue = @jira_client.Issue.find('JQWE-1')
    # puts @issue.to_json



    redirect_to action: 'find_issues'
  end

  def destroy
    session.data.delete(:jira_auth)
  end

  def query
    puts "REQ TOKEN"
    puts @jira_client.request_token.inspect
    # puts "REQ SECRET"
    # puts @jira_client.request_secret
    puts "ACCESS TOKEN"
    puts @jira_client.access_token.inspect
    # puts "ACCESS KEY"
    # puts @jira_client.access_key
    request_token = @jira_client.request_token 
    access_token  = @jira_client.access_token

    #@issue = session
    @issue = @jira_client.Issue.find('JQWE-1')
    puts @issue.to_json
  end

  def find_issues
    #
    # This shouldnt use a view. It should redirect to show_timesheets and pass the issues that this function finds
    #
    if params[:start] != nil
      start_time = params[:start]
    else
      start_time = 'startOfWeek()'
    end

    if params[:end] != nil
      end_time = params[:end]
    else
      end_time = 'endOfWeek()'
    end

    issues_url = "#{ENV['JIRA_URL']}/rest/api/2/search"
    issues_params = {
      :jql => "assignee = currentUser() or status changed during (#{start_time}, #{end_time}) by currentUser() ORDER BY updated DESC",
      :maxResults => 20
    }
    issues_headers = {
     :Authorization => 'Basic bXNvbG9tb246IVluZnRwbzEy',
     :content_type  => 'application/json',
     :params => issues_params
    }

    response = JSON.parse(RestClient.get issues_url, issues_headers)
    @issues = response['issues']
  end

  def show_timesheets (*options)
    if params[:view] != nil
      if params[:view] == "month"
        @view = "month"
        start_time = Date.today.beginning_of_month.strftime('%Y-%m-%d')
        end_time = Date.today.end_of_month.strftime('%Y-%m-%d')
      elsif params[:view] == "week"
        @view = "week"
        start_time = Date.today.beginning_of_week.strftime('%Y-%m-%d')
        end_time = Date.today.end_of_week.strftime('%Y-%m-%d')
      else
        @view = "day"
        start_time = Date.today.beginning_of_day.strftime('%Y-%m-%d')
        end_time = Date.today.end_of_day.strftime('%Y-%m-%d')
      end
    else
      @view = "week"
      start_time = Date.today.beginning_of_week.strftime('%Y-%m-%d')
      end_time = (Date.today.end_of_week - 2).strftime('%Y-%m-%d')
    end
    # if params[:start] != nil
    #   start_time = params[:start]
    # else
    #   start_time = Date.today.beginning_of_week.strftime('%Y-%m-%d')
    # end

    # if params[:end] != nil
    #   end_time = params[:end]
    # else
    #   end_time = (Date.today.end_of_week - 2).strftime('%Y-%m-%d')
    # end

    url = "#{ENV['JIRA_URL']}/rest/tempo-timesheets/3/worklogs"
    params = {
      :dateFrom => "#{start_time}", 
      :dateTo => "#{end_time}"
    }
    headers = {
     :Authorization => 'Basic bXNvbG9tb246IVluZnRwbzEy',
     :content_type  => 'application/json',
     :params => params
    }
    
    @time_sheets = JSON.parse(RestClient.get url, headers)

    @issues = Array.new

    # We get time_sheets in json from the API but it isn't the format I want
    # We receive json for each worklog - it is not a summarized amount of work for each ticket
    # This code below will group worklogs by each ticket
    @time_sheets.each_with_index do |time_sheet, index|
      is_duplicate_issue = false

      if index === 0
        new_issue = time_sheet['issue']
        worklog = time_sheet.slice('timeSpentSeconds', 'dateStarted', 'comment')
        new_issue['worklogs'] = Array.new
        new_issue['worklogs'].push(worklog)
        new_issue['total_time_logged_by_user'] = 0
        new_issue['total_time_logged_by_user'] += worklog['timeSpentSeconds']
        @issues.push(new_issue)
      else
        @issues.each do |issue|
          worklog = time_sheet.slice('timeSpentSeconds', 'dateStarted', 'comment')
          if time_sheet['issue']['key'] == issue['key']
            is_duplicate_issue = true
            issue['worklogs'].push(worklog)
            issue['total_time_logged_by_user'] += worklog['timeSpentSeconds']
          end
        end

        if is_duplicate_issue == false
          new_issue = time_sheet['issue']
          new_issue['worklogs'] = Array.new
          new_issue['worklogs'].push(worklog)
          new_issue['total_time_logged_by_user'] = 0
          new_issue['total_time_logged_by_user'] += worklog['timeSpentSeconds']
          @issues.push(new_issue)
        end
      end
    end

  end

  def log_meeting_time
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

  def log_issue_time
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
