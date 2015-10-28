# add any extra configuration options for your instance of JIRA,
# e.g. :use_ssl, :ssl_verify_mode, :context_path, :site
options = {
  :private_key_file => "rsakey.pem",
  :consumer_key => "06cc84ab493497e8bf4682c821eacd3b",
  :site => "https://thrillistmediagroup.atlassian.net",
  :context_path => ""
}

$jira_client = JIRA::Client.new(options)