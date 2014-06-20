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

  describe 'calculation methods' do
    let(:min_profile) { double(:min_profile, total_time: 1) }
    let(:max_profile) { double(:max_profile, total_time: 247) }
    let(:mediocre_profile) { double(:mediocre_profile, total_time: 13.5) }
    let(:profiles) { [min_profile, max_profile, mediocre_profile] }

    before(:each) do
      test_instance.stub(:instrumentations) do
        {
          min_profile: min_profile,
          max_profile: max_profile,
          mediocre_profile: mediocre_profile
        }
      end
    end

    describe '#min' do
      it 'should return the name and profile of the min' do
        test_instance.min.should eq [:min_profile, min_profile]
      end
    end

    describe '#max' do
      it 'should return the name and profile of the max' do
        test_instance.max.should eq [:max_profile, max_profile]
      end
    end

    describe '#median' do
      it 'should return the name and profile of the median' do
        test_instance.median.should eq [:mediocre_profile, mediocre_profile]
      end
    end

    describe '#mean_time' do
      it 'should return the mean time for all profiles' do
        total_time = profiles.reduce(0) { |sum, profile| sum + profile.total_time }
        test_instance.mean_time.should eq (total_time/profiles.size)
      end
    end

    describe '#standard_deviation' do
      it 'should return the standard deviation of the total times' do
        test_instance.standard_deviation.round(2).should eq 113.13
      end
    end
  end
end
