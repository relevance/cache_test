if RAILS_ENV == "test"
  require 'page_cache_test'
  require 'fragment_cache_test'
  
  Cosinux::PageCacheTest.configure
  Cosinux::FragmentCacheTest.configure
end

