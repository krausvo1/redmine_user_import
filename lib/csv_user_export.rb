module RedmineUserImport
  module CsvUserExport
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

    def export_users_to_csv(users, options = {}) 
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


    def user_to_csv(user, fields)
      fields.map do |column, _, get_value|
        formatter = CSV_COLUMN_FORMATTERS[column] || IDENTITY
        formatter.(get_value.(user))
      end
    end


  end
end