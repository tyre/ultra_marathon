require 'spec_helper'

describe UltraMarathon::Instrumentation do
  let(:test_class) do
    anonymous_test_class do
      include UltraMarathon::Instrumentation

      def run(&block)
        instrument { block.call }
      end
    end
  end

  let(:test_instance) { test_class.new }
  let(:start_time) { Time.local(1991, 1, 31, 15, 15, 00) }
  let(:end_time) { Time.local(1991, 1, 31, 16, 00, 20) }
  let(:run_block) do
    # This is going to be evaluated in context of the instance
    # so we need to wrap in an IIF to access `end_time`
    Proc.new do |end_time|
      Proc.new do
        Timecop.travel(end_time)
      end
    end.call(end_time)
  end

  subject(:run) { test_instance.run &run_block }

  before(:each) { Timecop.freeze(start_time) }
  after(:each) { Timecop.return }

  describe '#instrument' do

    describe 'method signature' do
      let(:run_block) { Proc.new { 'Bubbles!' } }

      it 'should return the result of the passed in block' do
        run.should eq 'Bubbles!'
      end
    end

    describe 'setting instance variables' do
      before(:each) { run }

      it 'should set the start_time' do
        test_instance.start_time.should eq start_time
      end

      it 'should set the end_time' do
        test_instance.end_time.to_i.should eq end_time.to_i
      end
    end
  end

  describe 'total_time' do
    before(:each) { run }

    it 'should return the total seconds elapsed' do
      test_instance.total_time.should eq 2720
    end
  end

  describe '#formatted_total_time' do
    before(:each) { run }

    it 'should return the total time, formatted' do
      test_instance.formatted_total_time.should eq '00:45:20'
    end
  end
end
