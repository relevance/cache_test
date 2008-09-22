module Cosinux #:nodoc:
  module PageCacheTest #:nodoc:
    
    def self.configure #:nodoc:
      ActionController::Base.perform_caching = true

      # overwrite class caching methods
      ActionController::Base.class_eval do
        include ClassCachingMethods
      end
      
      # include integration test methods
      Test::Unit::TestCase.class_eval do
        include IntegrationTestMethods
      end
    end

    module ClassCachingMethods #:nodoc:
      def self.included(base)
        base.extend(ClassMethods)
        base.class_eval do
          @@test_page_cached = []
          cattr_accessor :test_page_cached
          @@test_page_expired = []
          cattr_accessor :test_page_expired
        end
      end
      
      module ClassMethods #:nodoc:
        def cache_page(content, path)
          logger.info "Cached page: #{page_cache_file(path)}"
          test_page_cached.push(path)
        end

        def expire_page(path)
          logger.info "Expired page: #{page_cache_file(path)}"
          test_page_expired.push(path)
        end
      
        def cached?(path)
          test_page_cached.include?(path)
        end

        def expired?(path)
          test_page_expired.include?(path)
        end
      
        def reset_cache
          test_page_cached.clear
          test_page_expired.clear
        end
      end

      def cached?(options = {})
        self.class.cached?(url_for(options.merge({ :only_path => true, :skip_relative_url_root => true })))
      end

      def expired?(options = {})
        self.class.expired?(url_for(options.merge({ :only_path => true, :skip_relative_url_root => true })))
      end
    end

    # This module define method to validate the page caching logic of
    # your application in integration tests.
    #
    # == Testing page caching
    #
    # To test caching of the "/pages/about" and "/pages/contact"
    # pages, add a method like this: 
    #
    #   def test_caching
    #     assert_cache_pages("/pages/about", "/pages/contact")
    #   end
    #
    # The assert_cache method will
    # - first make sure that the urls are not cached,
    # - execute a get on each request,
    # - assert that the corresponding cache files have been created.
    #
    # You can also give a block to the assert_cache method. Instead
    # of executing a get on each url, it will yield the urls. For example:
    #
    #  def test_caching
    #    assert_cache_pages("/pages/about", "/pages/contact") do |url_about, url_contact|
    #      post url_about
    #      post url_contact
    #    end
    #  end
    #
    # == Testing expiring of pages
    #
    # You will also certainly want to check if your cached pages
    # expires when the user is doing some action. For that, here is
    # the assert_expire method:
    # 
    #   def test_expiring
    #     assert_expire_pages("/news/list", "/news/show/1") do |*urls|
    #       post "/news/delete/1"
    #     end
    #   end
    # 
    # Here the assert_expire_pages method will 
    # 
    # - check that the urls are cached,
    # - execute the post request,
    # - and assert that the urls are no more cached.
    #
    module IntegrationTestMethods
      # asserts that the list of given url are being cached
      def assert_cache_pages(*urls)
        ActionController::Base.reset_cache
      
        if block_given?
          yield *urls
        else
          urls.each { |url| get url }
        end

        urls.each do |url|
          assert_block("#{url.inspect} is not cached after executing block") do
            ActionController::Base.cached?(url)
          end
        end
      end

      # asserts that the list of given url are being expired
      def assert_expire_pages(*urls)
        ActionController::Base.reset_cache
        
        yield *urls

        urls.each do |url|
          assert_block("#{url.inspect} is cached after executing block") do
            ActionController::Base.expired?(url)
          end
        end
      end
    end
  end
end
