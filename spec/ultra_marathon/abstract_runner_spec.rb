require 'spec_helper'

describe UltraMarathon::AbstractRunner do
  let(:test_class) { anonymous_test_class(UltraMarathon::AbstractRunner) }
  let(:test_instance) { test_class.new }

  describe '#run!' do
    subject { test_instance.run! }

    describe 'with one run block' do
      before(:each) { test_class.send :run, &run_block }

      context 'when everything is fine' do
        let(:run_block) { Proc.new { logger.info 'Look at me go!' } }

        it 'should run the given block in the context of the instance' do
          subject
          test_instance.logger.contents.should include "Look at me go!\n"
        end

        it 'should be a success' do
          subject
          test_instance.success.should be
        end
      end

      context 'when things go wrong' do
        let(:run_block) { Proc.new { raise 'Benoit!' } }

        it 'should catch the error' do
          expect { subject }.to_not raise_error
        end

        it 'should logger.info the error message' do
          subject
          test_instance.logger.contents.should include 'Benoit!'
        end

        it 'should set success to false' do
          subject
          test_instance.success.should_not be
        end
      end
    end

    describe 'with multiple run blocks' do

      context 'when everything is fine' do

        before(:each) do
          test_class.send(:run, &->{ logger.info 'I am the Walrus' })
          test_class.send(:run, :yolo, &->{ logger.info 'Koo koo ka choo' })
        end

        it 'should run both blocks' do
          subject
          test_instance.logger.contents.should include 'I am the Walrus'
          test_instance.logger.contents.should include 'Koo koo ka choo'
        end
      end

      context 'when one goes awry' do
        before(:each) do
          test_class.send(:run, :walrus, &->{ raise 'I am the Walrus' })
          test_class.send(:run, :wat, &->{ logger.info 'Koo koo ka choo' })
        end

        it 'should still run the other' do
          subject
          test_instance.logger.contents.should include 'I am the Walrus'
          test_instance.logger.contents.should include 'Koo koo ka choo'
        end
      end

      context 'when one run relies on another' do
        context 'when everything is okay' do
          before(:each) do
            test_class.send(:run, :wat, requires: [:walrus], &->{ logger.info 'Koo koo ka choo' })
            test_class.send(:run, :walrus, &->{ logger.info 'I am the Walrus' })
          end

          it 'should run both blocks' do
            subject
            test_instance.logger.contents.should include 'I am the Walrus'
            test_instance.logger.contents.should include 'Koo koo ka choo'
          end

          it 'should run the parents before the children' do
            subject
            walrus_log_position = test_instance.logger.contents.index('I am the Walrus')
            wat_log_position = test_instance.logger.contents.index('Koo koo ka choo')
            walrus_log_position.should be < wat_log_position
          end
        end

        context 'when the parent fails' do
          before(:each) do
            test_class.send(:run, :wat, requires: [:walrus], &->{ logger.info 'Koo koo ka choo' })
            test_class.send(:run, :walrus, &->{ raise 'I am the Walrus!' })
          end

          it 'should logger.info the error' do
            subject
            test_instance.logger.contents.should include 'I am the Walrus!'
          end

          it 'should not run the child' do
            subject
            test_instance.logger.contents.should_not include 'Koo koo ka choo'
          end
        end
      end
    end
  end

  describe 'callbacks' do
    before(:each) { test_class.send :run, &run_block }

    subject { test_instance.run! }

    describe 'before_run callback' do
      let(:run_block) { Proc.new { logger.info 'Blastoff!' } }

      before(:each) do
        test_class.before_run ->{ logger.info '3-2-1' }
      end

      it 'should invoke before_run callbacks before run!' do
        subject
        test_instance.logger.contents.should include '3-2-1'
        test_instance.logger.contents.index('3-2-1').should be < test_instance.logger.contents.index('Blastoff!')
      end
    end

    describe 'after_run callback' do
      let(:run_block) { Proc.new { logger.info 'Blastoff!' } }

      before(:each) do
        test_class.after_run ->{ logger.info 'We have liftoff!' }
      end

      it 'should invoke before_run callbacks before run!' do
        subject
        test_instance.logger.contents.should include 'We have liftoff!'
        test_instance.logger.contents.index('We have liftoff!').should be > test_instance.logger.contents.index('Blastoff!')
      end
    end
  end

  describe '#reset' do
    it 'should change success to true' do
      test_instance.success = false
      test_instance.reset
      test_instance.success.should be
    end

    it 'returns itself' do
      test_instance.reset.should be test_instance
    end
  end
end
