# config/initializers/elasticsearch.rb
# TEMPORARILY COMMENTED OUT FOR TESTING

# require 'elasticsearch'

# begin
#   Elasticsearch::Model.client = Elasticsearch::Client.new(
#     url: ENV.fetch('ELASTICSEARCH_URL', 'http://localhost:9200'),
#     log: !Rails.env.test?
#   )
  
#   # Test connection in non-test environments
#   unless Rails.env.test?
#     Elasticsearch::Model.client.cluster.health
#   end
# rescue => e
#   if Rails.env.test?
#     # In test environment, just log the error and continue
#     Rails.logger.warn "Elasticsearch not available during tests: #{e.message}"
#   else
#     # In other environments, re-raise the error
#     raise e
#   end
# end
