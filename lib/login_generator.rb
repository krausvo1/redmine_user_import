module RedmineUserImport
  class LoginGenerator
    def self.for_user(user) 
      login = (prepare_name(user.firstname[0])[0] || "") + prepare_name(user.lastname)

      count = User.where("login REGEXP ?", "^#{login}[0-9]*$").count
      count > 0 ? "#{login}#{count}" : login
    end

    private
    def self.prepare_name(str)
      return "" if str.nil? 
      I18n.transliterate(str)
          .gsub(/[^a-z0-9_\-@\.]/i, '')
          .capitalize()
    end
  end
end