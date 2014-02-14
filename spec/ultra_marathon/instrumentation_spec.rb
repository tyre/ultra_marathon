require 'spec_helper'

describe UltraMarathon::Instrumentation do
  let(:test_class) do
    anonymous_test_class do
      include UltraMarathon::Instrumentation

      def run(&block)
        instrument(:run) { block.call }
      end
    end
  end

  let(:test_instance) { test_class.new }

  subject(:run) { test_instance.run &run_block }

  describe '#instrument' do
    let(:run_block) { Proc.new { 'Bubbles!' } }

    it 'should return the result of the passed in block' do
      run.should eq 'Bubbles!'
    end

    it 'should add the instrumentation information to the #instrumentations hash' do
      run
      profile = test_instance.instrumentations[:run]
      profile.should be_an UltraMarathon::Instrumentation::Profile
    end
  end
end
