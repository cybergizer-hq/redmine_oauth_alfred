require 'account_controller'
require 'json'
require 'openssl'

ENV["http_proxy"]=""

class RedmineOauthController < AccountController
  def oauth_alfred
    if Setting.plugin_redmine_alfred[:oauth_authentification]
      session[:back_url] = params[:back_url]
      hash = {:response_type => "code",
              :client_id => settings[:client_id],
              :scope => "user",
              :redirect_uri => oauth_alfred_callback_url(:protocol => 'https')}
      param_arr = []
      hash.each do |key , val|
        param_arr << "#{key}=#{val}"
      end
      params_str = param_arr.join("&")
      redirect_to settings[:url].gsub(/\/+$/, '') + "/oauth/authorize?#{params_str}"
    else
      password_authentication
    end
  end

  def oauth_alfred_callback
    if params[:error]
      flash[:error] = l(:access_denied)
      redirect_to signin_path
    else
      code = params[:code]
      connection = Faraday::Connection.new settings[:url].gsub(/\/+$/, '')#, :ssl => {:verify => false}
      response = connection.post do |req|
        req.url "/oauth/token"
        req.params["grant_type"] = "authorization_code"
        req.params["client_id"] = settings[:client_id]
        req.params["client_secret"] = settings[:client_secret]
        req.params["code"] = code
        req.params["redirect_uri"] = oauth_alfred_callback_url(:protocol => 'https')
      end
      token = JSON.parse(response.body)['access_token'].to_s
      response = connection.get do |req|
        req.url "/api/v1/users/me.json?access_token=#{token}"
      end

      info = JSON.parse(response.body)

      if info && info["id"]
        try_to_login info
      else
        flash[:error] = l(:unable_to_obtain_credentials)
        redirect_to signin_path
      end
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
end
