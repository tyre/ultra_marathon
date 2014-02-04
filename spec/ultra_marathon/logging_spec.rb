require 'spec_helper'

describe UltraMarathon::Logging do
  let(:test_class) do
    anonymous_test_class do
      include UltraMarathon::Logging
    end
  end

  let(:test_instance) { test_class.new }

  before(:each) { test_class.instance_variable_set(:@log_class, nil) }

  describe '.log_class' do
    let(:log_class) { anonymous_test_class }

    context 'passing a proc' do
      it 'it returns an instance of that class on instantiation' do
        test_class.send :log_class, ->{ log_class }
        test_instance.logger.should be_a log_class
      end
    end

    context 'passing a class' do
      it 'instantiates the logger as that class' do
        test_class.send :log_class, log_class
        test_instance.logger.should be_a log_class
      end
    end
  end

  describe '.logger' do
    it 'defaults to the UltraMarathon::Logger class' do
      test_instance.logger.should be_a UltraMarathon::Logger
    end
  end
end
