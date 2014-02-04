require 'spec_helper'

describe UltraMarathon::Store do
  let(:runner_class) do
    anonymous_test_class do
      attr_accessor :success, :name

      def initialize(name)
        @name = name.to_sym
      end

      # Helper methods for testing

      def succeed!
        self.success = true
        self
      end

      def fail!
        self.success = false
        self
      end
    end
  end

  let(:test_instance) { described_class.new(maintenances) }
  let(:maintenances) { [] }

  describe '#initialize' do
    let(:maintenances) do
      [ runner_class.new(:frank), runner_class.new(:harold) ]
    end

    it 'should add them and regurgitate them' do
      test_instance.sort_by(&:name).should eq maintenances
    end
  end

  describe '#<<' do
    it 'should add the maintenance to the storage' do
      test_maintenance = runner_class.new(:heraldo)
      test_instance << test_maintenance
      test_instance[:heraldo].should be test_maintenance
    end
  end

  describe '#add' do
    it 'should add the maintenance to the storage' do
      test_maintenance = runner_class.new(:heraldo)
      test_instance.add test_maintenance
      test_instance[:heraldo].should be test_maintenance
    end
  end

  describe '#pluck' do
    let(:maintenances) do
      [ runner_class.new(:frank), runner_class.new(:harold) ]
    end

    it 'should return an array of calling the block on each instance' do
      test_instance.pluck(&:name).sort.should eq [:frank, :harold]
    end
  end

  describe '#failed?' do
    let(:maintenances) { [ runner_class.new(:heraldo).fail! ] }

    it 'returns true if the maintenance was not successful' do
      test_instance.should be_failed :heraldo
    end

    it 'returns nil if the maintenance is not being stored' do
      test_instance.failed?(:juanita).should be_nil
    end
  end

  describe '#success?' do
    let(:maintenances) { [ runner_class.new(:heraldo).succeed! ] }

    it 'returns true if the maintenance was successful' do
      test_instance.should be_success :heraldo
    end

    it 'returns nil if the maintenance is not being stored' do
      test_instance.success?(:juanita).should be_nil
    end
  end

  describe '==' do
    let(:maintenances) { [ runner_class.new(:waldo), runner_class.new(:heraldo), runner_class.new(:geraldo) ] }
    let(:other_instance) { described_class.new(other_maintenances) }

    context 'when the names of the other maintenances are the same' do
      # purposefully a different order
      let(:other_maintenances) { [ runner_class.new(:heraldo), runner_class.new(:geraldo), runner_class.new(:waldo) ] }

      it 'should return true' do
        (other_instance == test_instance).should be true
      end
    end

    context 'when the names of the other maintenances are a subset' do
      let(:other_maintenances) { [ runner_class.new(:geraldo), runner_class.new(:waldo) ] }

      it 'should return false' do
        (other_instance == test_instance).should be false
      end
    end

    context 'when they are both equal' do
      let(:other_maintenances) { [] }

      it 'should return false' do
        (other_instance == test_instance).should be false
      end
    end
  end

  describe '!=' do
    let(:maintenances) { [ runner_class.new(:waldo), runner_class.new(:heraldo), runner_class.new(:geraldo) ] }
    let(:other_instance) { described_class.new(other_maintenances) }

    context 'when the names of the other maintenances are the same' do
      # purposefully a different order
      let(:other_maintenances) { [ runner_class.new(:heraldo), runner_class.new(:geraldo), runner_class.new(:waldo) ] }

      it 'should return false' do
        (other_instance != test_instance).should be false
      end
    end

    context 'when the names of the other maintenances are a subset' do
      let(:other_maintenances) { [ runner_class.new(:geraldo), runner_class.new(:waldo) ] }

      it 'should return true' do
        (other_instance != test_instance).should be true
      end
    end

    context 'when they are both equal' do
      let(:other_maintenances) { [] }

      it 'should return true' do
        (other_instance != test_instance).should be true
      end
    end
  end
end
