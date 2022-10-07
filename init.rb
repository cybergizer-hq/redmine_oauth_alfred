require 'redmine'
require_relative 'lib/redmine_alfred/hooks'
require_relative 'lib/redmine_alfred/account_controller_patch'

Redmine::Plugin.register :redmine_alfred do
  name 'Redmine Alfred omniauth plugin'
  author 'Ekaterina Barasheva'
  description 'This is a plugin for Redmine authentication with Alfred OAuth'
  version '0.0.1'
  url 'https://github.com/cybergizer-hq/redmine_oauth_alfred'
  author_url ''

  settings :default => {
    :client_id => "",
    :client_secret => "",
    :url => "",
    :oauth_authentification => false
  }, :partial => 'settings/alfred_settings'

  Rails.configuration.to_prepare do
    AccountController.send(:include, AccountControllerPatch)
  end
end
