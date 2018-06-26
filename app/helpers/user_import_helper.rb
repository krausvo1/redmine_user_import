module UserImportHelper
    def prefix_options(options, prefix)
        options.map do |o| 
            [o, "#{prefix}|#{o}"]
        end
    end
end
