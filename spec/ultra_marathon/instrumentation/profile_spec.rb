require 'spec_helper'
describe UltraMarathon::Instrumentation::Profile do
  let(:start_time) { Time.local(1991, 1, 31, 15, 15, 00, 0) }
  let(:end_time) { Time.local(1991, 1, 31, 16, 00, 20, 0) }
  let(:run_block) do
    # This is going to be evaluated in context of the instance
    # so we need to wrap in an IIF to access `end_time`
    Proc.new do |end_time|
      Proc.new do
        Timecop.travel(end_time)
        'Bubbles'
      end
    end.call(end_time)
  end

  let(:profile) { described_class.new(:speedy, &run_block) }

  subject(:run) { profile.call }

  before(:each) { Timecop.freeze(start_time) }
  after(:each) { Timecop.return }

  it 'should set its name' do
    profile.name.should be :speedy
  end

  describe '#call' do
    it 'should return the result of the block' do
      run.should eq 'Bubbles'
    end

    it 'should set the start_time' do
      run
      profile.start_time.should eq start_time
    end

    it 'should set the end_time' do
      run
      profile.end_time.to_i.should eq end_time.to_i
    end
  end

  describe 'total_time' do
    before(:each) { run }

    it 'should return the total seconds elapsed' do
      #Rounding because floats are a pain in the ass
      profile.total_time.round(3).should eq (end_time - start_time).round(3)
    end
  end

  describe '#formatted_total_time' do
    before(:each) { run }

    it 'should return the total time, formatted' do
      profile.formatted_total_time.should eq '00:45:20:000'
    end
  end
end
