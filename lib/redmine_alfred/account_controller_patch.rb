module RedmineAlfred
  module AccountControllerPatch
    def self.included(base)
      base.send(:include, LogoutMethods)
      base.class_eval do
        alias_method :logout_without_oauth, :logout
        alias_method :logout, :logout_with_oauth
      end
    end

    module LogoutMethods
      def logout_with_oauth
        if Setting.plugin_redmine_alfred[:oauth_authentification]
          logout_user
          return
        end

        logout_without_oauth
      end
    end
  end
end
