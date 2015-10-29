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
    if params[:view] != nil
      @view = params[:view]
      if params[:view] == "monthly"
        start_time = get_date_for "start_of_month"
        end_time = get_date_for "end_of_month"
        maxResults = 50
      elsif params[:view] == "weekly"
        start_time = get_date_for "start_of_week"
        end_time = get_date_for "end_of_week"
        maxResults = 20
      else
        start_time = get_date_for "start_of_day"
        end_time = get_date_for "end_of_day"
        maxResults = 20
      end
    else
      @view = "weekly"
      start_time = get_date_for "start_of_week"
      end_time = get_date_for "end_of_week"
      maxResults = 20
    end

    issues_url = "#{ENV['JIRA_URL']}/rest/api/2/search"
    issues_params = {
      :jql => "assignee = currentUser() or status changed during (#{start_time}, #{end_time}) by currentUser() ORDER BY updated DESC",
      :maxResults => maxResults
    }
    issues_headers = {
     :Authorization => 'Basic bXNvbG9tb246IVluZnRwbzEy',
     :content_type  => 'application/json',
     :params => issues_params
    }

    response = JSON.parse(RestClient.get issues_url, issues_headers)
    @issues = response['issues']
    @total_time_accross_tickets = 0
    @goal_time = business_hours_between Date.strptime(start_time), Date.strptime(end_time) 
    
    @issues.each do |issue|
      if issue['fields']['timespent'] == nil
        issue['fields']['timespent'] = 0
      end
      if issue['fields']['timeestimate'] == nil
        issue['fields']['timeestimate'] = 0
      end
      @total_time_accross_tickets += issue['fields']['timespent'] = 0
    end

    @sufficient_time_logged = get_sufficient_time_logged @goal_time, @total_time_accross_tickets
  end

  def get_sufficient_time_logged (goal_time, actual_time)
    if  actual_time >= goal_time * 60
      sufficient_time_logged = true
    else
      sufficient_time_logged = false
    end
    return sufficient_time_logged
  end

  def business_hours_between (date1, date2)
    business_days = 0
    date = date2
    while date > date1
     business_days = business_days + 1 unless date.saturday? or date.sunday?
     date = date - 1.day
    end
    business_days += 1
    business_hours = business_days * 8
  end

  def get_date_for (option)
    case option
    when "start_of_month"
      date = Date.today.beginning_of_month.strftime('%Y-%m-%d')
    when "end_of_month"
      date = Date.today.end_of_month.strftime('%Y-%m-%d')
    when "start_of_week"
      date = Date.today.beginning_of_week.strftime('%Y-%m-%d')
    when "end_of_week"
      date = Date.today.end_of_week.strftime('%Y-%m-%d')
    when "start_of_day"
      date = Date.today.beginning_of_day.strftime('%Y-%m-%d')
    when "end_of_day"
      date = Date.today.end_of_day.strftime('%Y-%m-%d')
    end
    return date
  end

  def show_timesheets
    if params[:view] != nil
      @view = params[:view]
      if params[:view] == "monthly"
        start_time = get_date_for "start_of_month"
        end_time = get_date_for "end_of_month"
      elsif params[:view] == "weekly"
        start_time = get_date_for "start_of_week"
        end_time = get_date_for "end_of_week"
      else
        start_time = get_date_for "start_of_day"
        end_time = get_date_for "end_of_day"
      end
    else
      @view = "weekly"
      start_time = get_date_for "start_of_week"
      end_time = get_date_for "end_of_week"
    end

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
    @total_time_accross_tickets = 0
    @goal_time = business_hours_between Date.strptime(start_time), Date.strptime(end_time)

    # We get time_sheets in json from the API but it isn't the format I want
    # We receive json for each worklog and tickets are a part of worklogs instead of the other way around
    # This code below will treat tickets uniquely and append the corresponding worklogs to tickets
    @time_sheets.each_with_index do |time_sheet, index|
      is_duplicate_issue = false

      if index === 0
        new_issue = time_sheet['issue']
        worklog = time_sheet.slice('timeSpentSeconds', 'dateStarted', 'comment')
        new_issue['worklogs'] = Array.new
        new_issue['worklogs'].push(worklog)
        new_issue['total_time_logged_by_user'] = 0
        new_issue['total_time_logged_by_user'] += worklog['timeSpentSeconds']

        @total_time_accross_tickets += new_issue['total_time_logged_by_user']

        @issues.push(new_issue)
      else
        @issues.each do |issue|
          worklog = time_sheet.slice('timeSpentSeconds', 'dateStarted', 'comment')
          if time_sheet['issue']['key'] == issue['key']
            is_duplicate_issue = true
            issue['worklogs'].push(worklog)
            issue['total_time_logged_by_user'] += worklog['timeSpentSeconds']

            @total_time_accross_tickets += issue['total_time_logged_by_user']
          end
        end

        if is_duplicate_issue == false
          new_issue = time_sheet['issue']
          new_issue['worklogs'] = Array.new
          new_issue['worklogs'].push(worklog)
          new_issue['total_time_logged_by_user'] = 0
          new_issue['total_time_logged_by_user'] += worklog['timeSpentSeconds']

          @total_time_accross_tickets += new_issue['total_time_logged_by_user']
          @issues.push(new_issue)
        end
      end
    end
    # End of formatting json for our issues with worklogs

    if @goal_time * 60 >= @total_time_accross_tickets
      @sufficient_time_logged = true
    else
      @sufficient_time_logged = false
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
