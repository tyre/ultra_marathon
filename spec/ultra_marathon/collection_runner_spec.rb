require 'timeout'
require 'spec_helper'

describe UltraMarathon::CollectionRunner do
  let(:test_class) { anonymous_test_class(UltraMarathon::CollectionRunner) }
  let(:test_instance) { test_class.new(collection, options, &run_block) }
  let(:collection) { [] }
  let(:options) { { name: :justice_league } }
  let(:run_block) { Proc.new { } }

  describe '#run!' do
    subject(:run_collection) { test_instance.run! }
    context 'with a single elements' do
      let(:collection) { [1, 3, 5, 7, 9] }
      let(:run_block) do
        proc { |item| logger.info("Chillin with homie #{item}")}
      end

      it 'should run each member of the collection' do
        run_collection
        collection.each do |item|
          sub_log = "Chillin with homie #{item}\n"
          test_instance.logger.contents.should include sub_log
        end
      end

      context 'when individual elements blow up' do
        let(:collection) { [1,2,3,4,5] }

        let(:run_block) do
          proc { |item| raise 'hell' if item % 2 == 0 }
        end

        it 'should not raise an error and set success to false' do
          expect { run_collection }.to_not raise_error
          test_instance.success.should be false
          test_instance.failed_sub_runners.length.should be 2
          test_instance.successful_sub_runners.length.should be 3
        end
      end
    end

    context 'with multiple arguments' do
      let(:collection) { [['Cassidy', 'Clay'], ['Tom', 'Jerry']] }
      let(:run_block) do
        proc { |homie1, homie2| logger.info("Chillin with homie #{homie1} & #{homie2}") }
      end

      it 'should run each member of the collection' do
        run_collection
        collection.each do |(homie1, homie2)|
          sub_log = "Chillin with homie #{homie1} & #{homie2}\n"
          test_instance.logger.contents.should include sub_log
        end
      end
    end

    context 'with a different iterator' do
      let(:number_array_class) do
        anonymous_test_class(Array) do
          def each_odd(&block)
            select(&:odd?).each(&block)
          end
        end
      end
      let(:collection) { number_array_class.new([1,2,3,4,5,6]) }
      let(:run_block) { proc { |odd_number| logger.info "#{odd_number} is an odd number!" } }
      let(:options) { { name: :this_is_odd, iterator: :each_odd } }

      it 'should use that iterator' do
        run_collection
        test_instance.logger.contents.should_not include "2 is an odd number!"
      end
    end

    context 'with a custom naming convention' do
      let(:options) { { name: :jimmy, sub_name: proc { |index, item| 'Sector' << (item ** 2).to_s } } }
      let(:collection) { [ 2, 4, 7] }

      it 'should correctly set the sub_runner names as requested' do
        run_collection
        test_instance.logger.contents.should include "Running 'Sector49' SubRunner"
      end
    end

    context 'passing threaded: true', slow: true do
      let(:options) { { name: :threaded, threaded: true } }
      let(:collection) { 0...100 }
      let(:run_block) { proc { |n| sleep(0.01) } }

      # Run 100 blocks that each sleep for a hundredth of a second.
      # The timeout can cause flakiness, but all we really care about is that
      # it runs in under a second, implying that it is either running the threads
      # or maybe failing and not doing anything. Other tests should control for
      # the latter scenario.

      it 'should run concurrently' do
        expect do
          Timeout::timeout(0.5) do
            run_collection
          end
        end.to_not raise_error
      end
    end
  end
end
