require 'forwardable'
require 'marathon/logger'
require 'active_support/concern'

module Marathon
  module Logging
    extend ActiveSupport::Concern

    ## Private Instance Methods

    def logger
      @logger ||= self.class.logger_class.new
    end

    module ClassMethods

      ## Public Class Methods

      # If the instance variable is callable, the result of invoking that block
      # is set to be the instance variable. Otherwise returns it, defaulting
      # to the included Logger class
      def logger_class
        if @logger_class && @logger_class.respond_to?(:call)
          @logger_class = @logger_class.call
        else
          @logger_class ||= Logger
        end
      end

      ## Private Class Methods

      private

      # Sets the log class. Can take a callable object or class
      def log_class(log_class)
        @logger_class = log_class
      end
    end
  end
end
