require 'ostruct'
require 'spec_helper'

describe UltraMarathon::Instrumentation::Store do

  let(:profiles) { [] }
  let(:test_instance) { described_class.new(profiles) }
  let(:profile_double_class) do
    anonymous_test_class(OpenStruct) do
      def initialize(name, attributes={})
        @name = name
        super(attributes)
      end

      def <=>(other_profile_double)
        total_time <=> other_profile_double.total_time
      end
    end
  end

  def profile_double(*args)
    profile_double_class.new(*args)
  end


  describe 'calculation methods' do
    let(:min_profile) { profile_double(:min_profile, total_time: 1) }
    let(:max_profile) { profile_double(:max_profile, total_time: 247) }
    let(:mediocre_profile) { profile_double(:mediocre_profile, total_time: 13.5) }
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
        test_instance.min.should eq min_profile
      end
    end

    describe '#max' do
      it 'should return the name and profile of the max' do
        test_instance.max.should eq max_profile
      end
    end

    describe '#median' do
      it 'should return the name and profile of the median' do
        test_instance.median.should eq mediocre_profile
      end
    end

    describe '#mean_runtime' do
      it 'should return the mean time for all profiles' do
        total_time = profiles.reduce(0) { |sum, profile| sum + profile.total_time }
        test_instance.mean_runtime.should eq (total_time/profiles.size)
      end
    end

    describe '#standard_deviation' do
      it 'should return the standard deviation of the total times' do
        test_instance.standard_deviation.round(2).should eq 113.13
      end
    end
  end
end
