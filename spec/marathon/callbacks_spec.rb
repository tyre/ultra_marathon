require 'spec_helper'

describe Marathon::Callbacks do
  let(:test_class) do
    anonymous_test_class do
      include Marathon::Callbacks
      attr_writer :bubble_count
      callbacks :before_bubbles, :after_bubbles, :on_error

      def bubbles(&block)
        begin
          invoke_before_bubbles_callbacks
          instance_exec &block
          invoke_after_bubbles_callbacks
        rescue StandardError => error
          invoke_on_error_callbacks(error)
        end
      end

      def bubble_count
        @bubble_count ||= 0
      end

      def increment_bubbles
        self.bubble_count += 1
      end

      def triple_bubbles
        self.bubble_count *= 3
      end

      def i_can_handle_errors!(error)
        self.bubble_count += error.message.to_i
      end
    end
  end

  let(:test_instance) { test_class.new }

  describe 'callback memoization' do
    it 'should add getter method' do
      test_class.should be_respond_to :before_bubbles_callbacks
      test_class.should be_respond_to :after_bubbles_callbacks
    end

    it 'should memoize an empty array' do
      test_class.before_bubbles_callbacks.should eq []
      test_class.after_bubbles_callbacks.should eq []
    end
  end

  describe 'invoking callbacks' do
    describe 'with lambdas' do
      describe 'that do not take arguments' do
        before(:each) do
          test_class.before_bubbles ->{ self.bubble_count = 12 }
          test_class.after_bubbles ->{ self.bubble_count += 1 }
          test_class.on_error ->{ self.bubble_count += 8 }
        end

        it 'should invoke the callbacks in order' do
          test_instance.bubbles { self.bubble_count /= 2 }
          test_instance.bubble_count.should be 7
        end

        it 'should not pass arguments if the lambda takes none' do
          # use a lambda, which will raise for incorrect arity
          test_instance.bubbles &->{ raise 'the roof!' }
          test_instance.bubble_count.should be 20
        end
      end

      describe 'with arguments' do
        before(:each) do
          test_class.on_error ->(e){ self.bubble_count = e.message.to_i }
        end

        it 'should pass the argument to the lambda' do
          test_instance.bubbles { raise '9001' }
          test_instance.bubble_count.should be 9001
        end

        it 'should throw an error if not enough arguments are passed' do
          expect {
            test_instance.send :invoke_on_error_callbacks
            }.to raise_error ArgumentError
        end
      end
    end

    describe 'passing in symbols' do
      describe 'that do not take arguments' do
        before(:each) do
          test_class.before_bubbles :increment_bubbles
          test_class.after_bubbles :triple_bubbles
        end

        it 'should invoke the callbacks in order' do
          test_instance.bubbles { self.bubble_count -= 2 }
          test_instance.bubble_count.should be -3
        end

        it 'allows passing the same symbol twice' do
          test_class.before_bubbles :increment_bubbles
          test_instance.bubbles { self.bubble_count -= 10 }
          test_instance.bubble_count.should be -24
        end

        describe 'when the callback passes arguments' do
          before(:each) { test_class.on_error :triple_bubbles }

          it 'calls the method successfully' do
            test_instance.bubbles { raise '9001' }
            test_instance.bubble_count.should be 3
          end
        end
      end

      describe 'with arguments' do
        before(:each) do
          test_class.on_error :i_can_handle_errors!
        end

        it 'should pass the argument to the lambda' do
          test_instance.bubbles { raise '9001' }
          test_instance.bubble_count.should be 9001
        end
      end
    end

    describe 'options' do
      describe ':if' do
        describe 'with a symbol' do
          before(:each) do
            test_class.before_bubbles :increment_bubbles, :if => :ready_to_party?
            test_class.before_bubbles :increment_bubbles
          end

          it 'should call the callback if the method is truthy' do
            test_instance.stub(:ready_to_party?).and_return true
            test_instance.bubbles { self.bubble_count *= 10 }
            test_instance.bubble_count.should be 20
          end

          it 'should not call the callback if the method is falsy' do
            test_instance.stub(:ready_to_party?).and_return false
            test_instance.bubbles { self.bubble_count *= 10 }
            test_instance.bubble_count.should be 10
          end
        end

        describe 'with a lambda' do
          before(:each) do
            test_class.before_bubbles :increment_bubbles, if: -> { ready_to_party? }
            test_class.before_bubbles :increment_bubbles
          end

          it 'should call the callback if the method is truthy' do
            test_instance.stub(:ready_to_party?).and_return true
            test_instance.bubbles { self.bubble_count *= 10 }
            test_instance.bubble_count.should be 20
          end

          it 'should not call the callback if the method is falsy' do
            test_instance.stub(:ready_to_party?).and_return false
            test_instance.bubbles { self.bubble_count *= 10 }
            test_instance.bubble_count.should be 10
          end
        end
      end

      describe ':unless' do
        describe 'with a symbol' do
          before(:each) do
            test_class.before_bubbles :increment_bubbles, :unless => :ready_to_party?
            test_class.before_bubbles :increment_bubbles
          end

          it 'should call the callback if the method is falsy' do
            test_instance.stub(:ready_to_party?).and_return true
            test_instance.bubbles { self.bubble_count *= 10 }
            test_instance.bubble_count.should be 10
          end

          it 'should not call the callback if the method is truthy' do
            test_instance.stub(:ready_to_party?).and_return false
            test_instance.bubbles { self.bubble_count *= 10 }
            test_instance.bubble_count.should be 20
          end
        end

        describe 'with a lambda' do
          before(:each) do
            test_class.before_bubbles :increment_bubbles, unless: ->{ ready_to_party? }
            test_class.before_bubbles :increment_bubbles
          end

          it 'should call the callback if the method is falsey' do
            test_instance.stub(:ready_to_party?).and_return true
            test_instance.bubbles { self.bubble_count *= 10 }
            test_instance.bubble_count.should be 10
          end

          it 'should not call the callback if the method is truthy' do
            test_instance.stub(:ready_to_party?).and_return false
            test_instance.bubbles { self.bubble_count *= 10 }
            test_instance.bubble_count.should be 20
          end
        end
      end

      describe ':context' do
        let(:other_walrus) { test_class.new }

        describe 'with a symbol' do
          before(:each) do
            test_class.before_bubbles :increment_bubbles, context: other_walrus
            test_class.before_bubbles :increment_bubbles
          end

          it 'should call the callback on the other object' do
            test_instance.bubbles { self.bubble_count *= 10 }
            test_instance.bubble_count.should be 10
            other_walrus.bubble_count.should be 1
          end
        end

        describe 'with a block' do
          before(:each) do
            test_class.before_bubbles(Proc.new { increment_bubbles; triple_bubbles }, context: other_walrus)
            test_class.before_bubbles :increment_bubbles
          end

          it 'should call the block on the other object' do
            test_instance.stub(:ready_to_party?).and_return true
            test_instance.bubbles { self.bubble_count *= 10 }
            test_instance.bubble_count.should be 10
            other_walrus.bubble_count.should be 3
          end
        end
      end
    end
  end
end
