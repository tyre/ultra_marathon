require 'spec_helper'

describe UltraMarathon::SubRunner do
  let(:test_class) do
    anonymous_test_class do
      attr_writer :bubble_count

      def bubble_count
        @bubble_count ||= 0
      end

      private

      def increment_bubbles
        self.bubble_count += 1
      end

      def triple_bubbles
        self.bubble_count *= 3
      end
    end
  end

  let(:test_instance) { described_class.new(options, run_block) }
  let(:options) do
    { context: context, name: name }
  end
  let(:name) { :frank }
  let(:context) { test_class.new }

  context '#run!' do
    let(:run_block) { ->{ increment_bubbles } }
    subject { test_instance.run! }

    it 'runs in the context that was passed in' do
      subject
      context.bubble_count.should be 1
    end

    it 'returns itself' do
      subject.should be test_instance
    end

    it 'starts the logs with its name' do
      subject
      test_instance.logger.contents.should be_start_with "Running '#{name}' SubRunner"
    end

    describe 'logging' do
      let(:run_block) { ->{ logger.info('Draws those who are willing, drags those who are not.') } }

      it 'logs to the sub maintenance' do
        subject
        test_instance.logger.contents.should include 'Draws those who are willing, drags those who are not.'
      end
    end

    describe 'instrumentation' do
      let(:options) do
        { context: context, name: name, instrument: true }
      end

      it 'should log the total time' do
        subject
        test_instance.logger.contents.should include 'Total Time:'
      end

      describe 'when instrument: false is set' do
        let(:options) do
          { context: context, name: name, instrument: false }
        end

        it 'should not log total time' do
          test_instance.logger.contents.should_not include 'Total Time:'
        end
      end
    end

    describe 'callbacks' do
      it 'should invoke before_run callbacks once' do
        expect(test_instance).to receive(:invoke_before_run_callbacks).once
        subject
      end

      it 'should invoke after_run callbacks once' do
        expect(test_instance).to receive(:invoke_after_run_callbacks).once
        subject
      end

      it 'should invoke before_run callbacks, the subcontext, then after_run callbacks' do
        sub_context = double(:sub_context)
        test_instance.stub(:sub_context) { sub_context }
        expect(test_instance).to receive(:invoke_before_run_callbacks).ordered
        expect(sub_context).to receive(:call).ordered
        expect(test_instance).to receive(:invoke_after_run_callbacks).ordered
        subject
      end
    end
  end
end
