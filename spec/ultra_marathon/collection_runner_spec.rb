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

      it 'should run run each member of the collection' do
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
        end
      end
    end
  end
end
