module RedmineUserImport
  module CsvParser
    PARSER = {
      "csv" => ->(field) {
        ->(row){ row[field] }
      },
      "val" => ->(value) {
        ->(row){ value }
      }
    }

    def self.get_parser(text)
      type, val = text.split('|')
      PARSER[type].(val)
    end

    def self.get_parsers(parser_defs)
      parser_defs
      .reject(&:blank?)
      .map { |p| get_parser(p) }
    end

    def inititalize(field_defs)
      @parsers = field_defs.transform_values do |parser_defs|
        get_parsers(parser_defs)
      end
    end

    def self.parse(parser, row)
      result = parser.(row)
      result.blank? ? nil : result
    end

    def parse_row(row)
      @parsers.transform_values do |parsers|
        value = parsers.reduce(nil) do |value, parser|
          value || parse(parser, row)
        end
        value
      end
    end
  end
end