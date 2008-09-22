module Cosinux
  module FragmentCacheTest #:nodoc:
    class NoRequestInBlockError < StandardError #:nodoc:
    end

    class NoControllerDefinedError < StandardError #:nodoc:
    end

    # This fragment store remembers the fragments that have been 
    # cached or deleted so that we can use it to check if
    # caching or expiring of fragment was done or not.
    class TestStore < ActionController::Caching::Fragments::MemoryStore #:nodoc:
      attr_reader :written, :deleted, :deleted_matchers
      
      def initialize
        super
        @written = []
        @deleted = []
        @deleted_matchers = []
      end
                    
      def reset
        @data.clear
        @written.clear
        @deleted.clear
        @deleted_matchers.clear
      end
      
      def write(name, value, options = nil)
        @written.push(name)
        super
      end
      
      def delete(name, options = nil)
        @deleted.push(name)
        super
      end
      
      def delete_matched(matcher, options = nil)
        @deleted_matchers.push(matcher)
      end
      
      def written?(name)
        @written.include?(name)
      end
      
      def deleted?(name)
        @deleted.include?(name) || @deleted_matchers.detect { |matcher| name =~ matcher }
      end
    end
    
    def self.configure #:nodoc:
      ActionController::Base.perform_caching = true
      ActionController::Base.fragment_cache_store = TestStore.new
      
      Test::Unit::TestCase.class_eval do
        include Assertions
      end
    end
    
    # This module define method to validate the fragment and action caching logic of
    # your application in both integration and functional tests.
    #
    # == Testing action caching
    #
    # To test caching of the "bar" action of the foo "controller"
    # in an integration test, do
    #
    #   assert_cache_actions(:controller => "foo", :action => "bar") do
    #     get "/foo/bar"
    #   end
    #
    # The assert_cache_actions method will
    # - first make sure that the actions are not cached,
    # - yield the given block
    # - assert that the corresponding action fragment have been stored.
    #
    # == Testing expiring of actions
    #
    # To check that some actions are expired, use the assert_expire_actions method:
    # 
    #   assert_expire_actions(:controller => "foo", :action => "bar") do |*urls|
    #     post "/foo/expire_cache"
    #   end
    # 
    # Here the assert_expire_actions method will 
    # 
    # - check that the actions fragments are cached,
    # - execute the post request,
    # - and assert that the fragments are no more cached.
    #
    # In functional test, there can be only one controller, so you are
    # not required to give the :controller option and if they are no
    # parameters to the action, you can simply call 
    #
    #   assert_cache_actions(:foo, :bar) do
    #     get :bar
    #     get :foo
    #   end
    #
    # == Testing fragments caching
    #
    # To check that your fragments are cached when doing some action,
    # do
    #
    #   assert_cache_fragments(:controller => "foo", :action => "bar", :action_suffix => "baz") do
    #     get "/foo/bar"
    #   end
    #
    # == Testing expiration of fragments
    #
    # To check that your fragments are expired when doing some action,
    # do
    #
    #   assert_expire_fragments(:controller => "foo", :action => "bar", :action_suffix => "baz") do
    #     get "/foo/expire"
    #   end
    #
    # In functional test, your not required to give the :controller option.
    module Assertions
      # asserts that the list of given fragment name are being cached
      def assert_cache_fragments(*names)
        # in integration test, we need the know the controller
        check_options_has_controller(names) if self.is_a?(ActionController::IntegrationTest)
        
        fragment_cache_store.reset
        
        yield *names
        
        # if there is no variable @controller, then we haven't done any request
        raise NoRequestInBlockError.new("no request was send while executing block.") if @controller.nil?
        
        names.each do |name|
          assert_block("#{name.inspect} is not cached after executing block") do
            fragment_cache_store.written?(@controller.fragment_cache_key(name))
          end
        end
      end

      # assert that the list of given fragment are being expired
      def assert_expire_fragments(*names)
        check_options_has_controller(names) if self.is_a?(ActionController::IntegrationTest)
        
        fragment_cache_store.reset
        
        yield *names

        raise NoRequestInBlockError.new("no request was send while executing block.") if @controller.nil?
        
        names.each do |name|
          assert_block("#{name.inspect} is cached after executing block") do
            fragment_cache_store.deleted?(@controller.fragment_cache_key(name))
          end
        end
      end

      # assert that the given actions are being cached
      def assert_cache_actions(*actions)
        check_options_has_controller(actions) if self.is_a?(ActionController::IntegrationTest)
        
        fragment_cache_store.reset
        
        yield *actions
       
        raise NoRequestInBlockError.new("no request was send while executing block.") if @controller.nil?
        
        actions.each do |action|
          action = { :action => action } unless action.is_a?(Hash)
          assert_block("#{action.inspect} is not cached after executing block") do
            fragment_cache_store.written?(@controller.fragment_cache_key(action))
          end
        end
      end

      # assert that the given actions are being expired
      def assert_expire_actions(*actions)
        check_options_has_controller(actions) if self.is_a?(ActionController::IntegrationTest)
        
        fragment_cache_store.reset
        
        yield *actions
        
        raise NoRequestInBlockError.new("no request was send while executing block.") if @controller.nil?
        
        actions.each do |action|
          action = { :action => action } unless action.is_a?(Hash)
          assert_block("#{action.inspect} is cached after executing block") do
            fragment_cache_store.deleted?(@controller.fragment_cache_key(action))
          end
        end
      end

      private
      def fragment_cache_store
        ActionController::Base.fragment_cache_store
      end
      
      def check_options_has_controller(options)
        if option = options.detect { |option| option[:controller].nil? }
          raise NoControllerDefinedError.new("no controller given in option #{option.inspect} in integration test")
        end
      end
    end
  end
end
