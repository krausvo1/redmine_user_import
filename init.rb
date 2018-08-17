require 'redmine'
require_dependency 'custom_fields_helper'
require 'csv_parser'
require 'login_generator'

Redmine::Plugin.register :redmine_user_import do
  name 'Redmine User Import plugin'
  author 'Hiroyuki SHIRAKAWA, Thorsten-Michael Deinert'
  description 'User import from csv'
  version '0.2.0'
  url 'https://github.com/thorsten-de/redmine_user_import'
  author_url 'http://twitter.com/#!/shrkwh, http://d.hatena.ne.jp/shrkw/'

#  permission :import_user_csv, :user_import => :index
  # caption localization does not work.
  menu :admin_menu, :user_import, { :controller => 'user_import', :action => 'index' }, :caption => :user_import, after: :users, :if => Proc.new {User.current.admin?}, :html => {:class => 'icon groups'}
end


class IncludeSelect2ViewListener < Redmine::Hook::ViewListener

  # Adds javascript and stylesheet tags
  def view_layouts_base_html_head(context)
      javascript_include_tag('https://cdnjs.cloudflare.com/ajax/libs/select2/4.0.6-rc.0/js/select2.min.js') +
      stylesheet_link_tag('https://cdnjs.cloudflare.com/ajax/libs/select2/4.0.6-rc.0/css/select2.min.css')
  end
end
  
