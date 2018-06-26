require 'redmine'
require_dependency 'custom_fields_helper'

Redmine::Plugin.register :redmine_user_import do
  name 'Redmine User Import plugin'
  author 'Hiroyuki SHIRAKAWA, Thorsten-Michael Deinert'
  description 'User import from csv'
  version '0.2.0'
  url 'https://github.com/thorsten-de/redmine_user_import'
  author_url 'http://twitter.com/#!/shrkwh, http://d.hatena.ne.jp/shrkw/'

#  permission :import_user_csv, :user_import => :index
  # caption localization does not work.
  menu :account_menu, :user_import, { :controller => 'user_import', :action => 'index' }, :caption => :user_import, :before => :logout, :if => Proc.new {User.current.admin?}
end
