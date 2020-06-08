get 'oauth_alfred', :to => 'redmine_oauth#oauth_alfred'
get 'oauth2callback', :to => 'redmine_oauth#oauth_alfred_callback', :as => 'oauth_alfred_callback'