require 'baseplate/recipe'
module Baseplate
  class Main
    def self.run
      puts "baseplate Version 0.0.0"

      dryrun = false
      filename = nil

      while arg = ARGV.shift
        case arg
        when "-n"
          dryrun = true
        when "--"
          break
        else
          if arg.start_with?("-")
            raise "E: Switch '%s' unknown" % arg
          end
          filename = arg
        end
      end

      filename ||= ARGV.shift
      if filename.nil?
        return usage
      end

      Recipe.run filename, {:dryrun => dryrun}
    end

    def self.usage
      puts "Usage:"
      puts
      puts "  baseplate recipe.bp"
      puts "    -- Apply recipe.bp to this system"
    end
  end
end
