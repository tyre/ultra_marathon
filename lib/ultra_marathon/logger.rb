require 'forwardable'

module UltraMarathon
  class Logger
    extend Forwardable
    NEW_LINE = "\n".freeze

    ## Public Instance Methods

    # Adds the line plus a newline
    def info(line)
      return if line.empty?
      log_string << padded_line(line)
    end

    def error(error)
      if error.is_a? Exception
        log_formatted_error(error)
      else
        info error
      end
    end

    # Returns a copy of the log data so it cannot be externally altered
    def contents
      log_string.dup
    end

    alias_method :emerg, :info
    alias_method :warning, :info
    alias_method :notice, :info
    alias_method :debug, :info
    alias_method :err, :error
    alias_method :panic, :emerg
    alias_method :warn, :warning

    private

    ## Private Instance Methods

    def log_string
      @log_string ||= ''
    end

    def padded_line(line)
      if line.end_with? NEW_LINE
        line
      else
        line << NEW_LINE
      end
    end

    def log_formatted_error(error)
      info error.message
      formatted_backtrace = error.backtrace.map.with_index do |backtrace_line, line_number|
        sprintf('%03i) %s', line_number, backtrace_line)
      end
      info formatted_backtrace.join("\n")
    end
  end
end
