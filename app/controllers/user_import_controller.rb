require 'tempfile'
require 'csv'

class UserImportController < ApplicationController
  before_action :require_admin
  helper :custom_fields


  USER_ATTRS = [:firstname, :lastname, :mail]
  RULE_COUNT = 1


  def index
  end

  def match
    # params
    file = params[:file]
    splitter = params[:splitter]
    wrapper = params[:wrapper]
    encoding = params[:encoding] unless params[:encoding].blank?

    @samples = []
    @headers = []
    @attrs = []

    

    # save import file
    @original_filename = file.original_filename
    tmpfile = Tempfile.new("redmine_user_importer", :encoding =>'ascii-8bit')
    if tmpfile
      data = file.read
      encoding ||= CharDet.detect(data)["encoding"]
      tmpfile.write(data)
      tmpfile.close
      tmpfilename = File.basename(tmpfile.path)
      if !$tmpfiles
        $tmpfiles = Hash.new
      end
      $tmpfiles[tmpfilename] = tmpfile
    else
      flash.now[:error] = "Cannot save import file."
      return
    end

    session[:importer_tmpfile] = tmpfilename
    session[:importer_splitter] = splitter
    session[:importer_wrapper] = wrapper
    session[:importer_encoding] = encoding
    # display content
    begin
      CSV.open(tmpfile.path, {:headers=>true, :encoding=>encoding, :quote_char=>wrapper, :col_sep=>splitter}) do |csv|
        @samples = csv.read
        @headers = csv.headers  
      end
    rescue => ex
      flash.now[:error] = ex.message
    end


    # fields
    @attrs = USER_ATTRS.map do |attr|
      [t("field_#{attr}"), attr]
    end

    @custom_required = User
      .new
      .custom_field_values
      .select(&:required?)
      .map(&:custom_field)

    @header_options = @headers.map { |h| ["#csv|{h}", h]}
    
    @groups = Group.givable.sort.map { |g| [g.name, g.id]}
  end

  def result
    tmpfilename = session[:importer_tmpfile]
    splitter = session[:importer_splitter]
    wrapper = session[:importer_wrapper]
    encoding = session[:importer_encoding]

    if tmpfilename
      tmpfile = $tmpfiles[tmpfilename]
      if tmpfile == nil
        flash.now[:error] = l(:message_missing_imported_file)
        return
      end
    end

    # CSV fields map
    fields_map = params[:fields_map]
    # DB attr map

    user_parser = RedmineUserImport::CsvParser.new fields_map[:user]
    custom_field_parser = RedmineUserImport::CsvParser.new fields_map[:custom_fields]

    @handle_count = 0
    @line_count = 1
    @failed_rows = []
    @imported = []
    
    row_group_ids = params["row_group_ids"] || {}
    default_groups = (params["default_group_ids"] || []).map &:to_i



    CSV.foreach(tmpfile.path, {:headers=>true, :encoding=>encoding, :quote_char=>wrapper, :col_sep=>splitter}).with_index do |row, index|
      user_values =  user_parser.parse_row(row).reject { |_, data| data.nil? }
      
      user_values["custom_field_values"] = 
        custom_field_parser.parse_row(row).reject { |_, data| data.nil? }

      
      user =  User.find_by_login(user_values["login"]) if (user_values["login"]) 
      unless user
        user = User.new({
          generate_password: true,
          must_change_passwd: true,
          mail_notification: Setting.default_notification_option,
          language: Setting.default_language,
        }.merge(user_values))        

        # generate user login if not set
        user.login = RedmineUserImport::LoginGenerator.for_user(user)
        

        if user.save
          # set user groups for new user
          p row_group_ids
          user_groups = (row_group_ids[index.to_s] || []).map &:to_i
          user.group_ids = Set.new(default_groups).merge(user_groups)

          Mailer.account_information(user, user.password).deliver
          @imported << [@line_count, row, user]
        else
          logger.info(user.errors.full_messages)
          @failed_rows << [@line_count, row, user.errors.full_messages] 
        end
        
        @handle_count += 1
      end
      
      @line_count += 1
    end

    
    
    @failed_count = @failed_rows.size
    if @failed_count > 0
      #failed_rows = @failed_rows.sort
      @headers = @failed_rows.first[1].headers
    end

#    render json: {count: @handle_count, failed: @failed_rows}
  end

  def finish
    users = params["users"] || []
    default_groups = params["default_group_ids"].map &:to_i

    @users = users.map do |user_id, user_params|
      user = User.find(user_id)
      if user
        user_groups = (user_params["group_ids"] || []).map &:to_i
        user.group_ids = Set.new(user.group_ids).merge(default_groups).merge(user_groups)
        user.save
      end
      
      user
    end
  end

end
