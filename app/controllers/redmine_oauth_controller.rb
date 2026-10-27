require 'account_controller'
require 'json'
require 'openssl'
require 'securerandom'
require 'uri'

ENV["http_proxy"]=""

class RedmineOauthController < AccountController
  def oauth_alfred
    if Setting.plugin_redmine_alfred[:oauth_authentification]
      session[:back_url] = params[:back_url]
      session[:alfred_oauth_state] = SecureRandom.hex(16)
      query = URI.encode_www_form(
        :response_type => "code",
        :client_id => settings[:client_id],
        :scope => "user",
        :redirect_uri => oauth_alfred_callback_url(:protocol => 'https'),
        :state => session[:alfred_oauth_state]
      )
      redirect_to "#{alfred_url}/oauth/authorize?#{query}"
    else
      password_authentication
    end
  end

  def oauth_alfred_callback
    expected_state = session.delete(:alfred_oauth_state)

    if params[:error]
      flash[:error] = l(:access_denied)
      return redirect_to signin_path
    end

    unless expected_state.present? &&
           ActiveSupport::SecurityUtils.secure_compare(expected_state, params[:state].to_s)
      Rails.logger.warn "[redmine_alfred] OAuth state missing or mismatched"
      return alfred_login_failed
    end

    # Secrets go in the POST body and the Authorization header, never in the
    # URL, so they don't end up in access logs on either side.
    token_response = alfred_connection.post('/oauth/token') do |req|
      req.headers['Content-Type'] = 'application/x-www-form-urlencoded'
      req.body = URI.encode_www_form(
        :grant_type => "authorization_code",
        :client_id => settings[:client_id],
        :client_secret => settings[:client_secret],
        :code => params[:code],
        :redirect_uri => oauth_alfred_callback_url(:protocol => 'https')
      )
    end
    token = alfred_parse_json(token_response, 'oauth/token')&.dig('access_token').to_s
    return alfred_login_failed if token.empty?

    info_response = alfred_connection.get('/api/v1/users/me.json') do |req|
      req.headers['Authorization'] = "Bearer #{token}"
    end
    info = alfred_parse_json(info_response, 'users/me')

    if info && info["id"]
      try_to_login info
    else
      alfred_login_failed
    end
  end

  def try_to_login info
    params[:back_url] = session[:back_url]
    session.delete(:back_url)
    email = EmailAddress.where(address: info["email"]).first
    if email.nil?
      user = User.new
      user.firstname = info["first_name"]
      user.lastname = info["last_name"]
      user.login = info["email"]
      user.mail = info["email"]
      user.random_password
      user.register

      user.activate
      user.last_login_on = Time.now
      if user.save
        self.logged_user = user
        flash[:notice] = l(:notice_account_activated)
        redirect_to my_account_path
      else
        yield if block_given?
      end
    else
      user = email.user
      if user.active?
        successful_authentication(user)
      else
        # Redmine 2.4 adds an argument to account_pending
        if Redmine::VERSION::MAJOR > 2 or
          (Redmine::VERSION::MAJOR == 2 and Redmine::VERSION::MINOR >= 4)
          account_pending(user)
        else
          account_pending
        end
      end
    end
  end

  def settings
    @settings ||= Setting.plugin_redmine_alfred
  end

  private

  def alfred_url
    settings[:url].to_s.gsub(/\/+$/, '')
  end

  # Server-side connection to Alfred. When CF_ACCESS_CLIENT_ID and
  # CF_ACCESS_CLIENT_SECRET are set in the environment, every request carries
  # the Cloudflare Access service-token headers.
  def alfred_connection
    headers = {}
    if ENV['CF_ACCESS_CLIENT_ID'].present? && ENV['CF_ACCESS_CLIENT_SECRET'].present?
      headers['CF-Access-Client-Id'] = ENV['CF_ACCESS_CLIENT_ID']
      headers['CF-Access-Client-Secret'] = ENV['CF_ACCESS_CLIENT_SECRET']
    end
    Faraday.new(:url => alfred_url, :headers => headers)
  end

  # Returns parsed JSON, or nil on a non-2xx status or a non-JSON body (for
  # example a Cloudflare 401/403). Logs the status only, never the body.
  def alfred_parse_json(response, label)
    unless response.success?
      Rails.logger.warn "[redmine_alfred] #{label} failed: HTTP #{response.status}"
      return nil
    end
    JSON.parse(response.body)
  rescue JSON::ParserError
    Rails.logger.warn "[redmine_alfred] #{label} returned non-JSON (HTTP #{response.status})"
    nil
  end

  def alfred_login_failed
    flash[:error] = l(:unable_to_obtain_credentials)
    redirect_to signin_path
  end
end
