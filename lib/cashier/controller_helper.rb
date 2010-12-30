# Hooks into ApplicationController's write_fragment method.
# write_fragment is used for action and fragment caching.
# Create an alias method chain to call our customer method
# which stores the associated key with the tag in a 
# Redis Set. Then we can expire all those keys from anywhere
# in the code using Rails.cache.delete
#
# I use alias_method_chain instead of calling 'super'
# because there is a very rare case where someone 
# may have redfined 'write_fragment' in their own 
# controllers. Using an alias method chain
# keeps those methods intact.

module Cashier
  module ControllerHelper
    def self.included(klass)
      klass.class_eval do
        def write_fragment_with_tagged_key(key, content, options = nil)
          if options && options[:tag] 
            passed_tags = case options[:tag].class.to_s
                   when 'Proc', 'Lambda'
                     options[:tag].call(self)
                   else 
                     options[:tag]
                   end
            tags = passed_tags.is_a?(Array) ? passed_tags : [passed_tags]
            tags.each do |tag|
              Cashier.redis.sadd tag, fragment_cache_key(key)
              Cashier.redis.sadd Cashier::STORAGE_KEY, tag
            end
          end
          write_fragment_without_tagged_key(key, content, options)
        end
        alias_method_chain :write_fragment, :tagged_key
      end
    end
  end
end  
