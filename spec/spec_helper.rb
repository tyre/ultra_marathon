require 'fileutils'
require 'awesome_print'
require 'timecop'
require 'ultra_marathon'
require 'rspec'
require 'rspec/autorun'
require 'support/test_helpers'

include TestHelpers

# TODO Google this when I have Wifi
# TEST_TMP_DIRECTORY = 'test_tmp'.freeze

# before(:suite) do
#   Dir.mkdir_p(TEST_TMP_DIRECTORY)
#   Dir.foreach(TEST_TMP_DIRECTORY) do |file_name|
#     File.delete(file_name)
#   end
# end
