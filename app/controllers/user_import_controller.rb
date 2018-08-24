require 'tempfile'
require 'csv'

class UserImportController < ApplicationController
  before_action :require_admin
  helper :custom_fields

  USER_ATTRS = [:firstname, :lastname, :mail]
  RULE_COUNT = 1

  def index
    # do nothing, just render action's default template
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
    tmpfile = Tempfile.new("redmine_user_importer", encoding: 'ascii-8bit')
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
      CSV.open(tmpfile.path, headers: true, encoding: encoding, quote_char: wrapper, col_sep: splitter) do |csv|
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

    @custom_required = UserCustomField.where(is_required: true)

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

    CSV.foreach(tmpfile.path, headers: true, encoding: encoding, quote_char: wrapper, col_sep: splitter).with_index do |row, index|
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

        # set default preferences
        user.pref[:comments_sorting] = 'desc';

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
  end


  EXPORT_COLUMNS = [
    :login,
    :firstname,
    :lastname,
    :mail,
    :admin,
    :created_on,
    :last_login_on,
    :status,
    :groups
  ]
  
  def export()
    users = User.all

    fields = EXPORT_COLUMNS.map { |col| [col, l("field_#{col}"), ->(user) {user.send(col)}]}
    fields += UserCustomField.all.map { |col| [col.name, col.name, ->(user) { user.custom_value_for(col)}]}

    send_data(UserImportController::export_users_to_csv(users,
      fields: fields
      ),
      type: 'text/csv; header=present',
      filename: "#{Date.today()}_users.csv"
    )
  end

  private

  USER_STATUS = [
    :status_active,
    :status_registered,
    :status_locked
  ]

  CSV_COLUMN_FORMATTERS = {
      status: ->(status) { l(USER_STATUS[status]) },
      groups: ->(groups) { groups.join(", ") }
  }

  IDENTITY = ->(x) { x }

  def self.export_users_to_csv(users, options = {}) 
    fields = options[:fields] || []

    CSV.generate(
      encoding: options[:encoding] || 'utf-8',
      force_quotes: true
      ) do |csv|
      # export csv header p
      csv << fields.map { |_, column_name,_| column_name }

      # export users
      users
        .map { |u| user_to_csv(u, fields)}
        .reduce(csv, :<<)
    end
  end


  def self.user_to_csv(user, fields)
    fields.map do |column, _, get_value|
      formatter = CSV_COLUMN_FORMATTERS[column] || IDENTITY
      formatter.(get_value.(user))
    end
  end
end
