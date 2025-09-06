# config/initializers/kafka.rb

require 'kafka'

begin
  $kafka = Kafka.new(
    seed_brokers: [ENV.fetch('KAFKA_BROKERS', 'localhost:9092')],
    client_id: 'myapp'
  )
  
  # Test connection in non-test environments
  unless Rails.env.test?
    $kafka.fetch_cluster_info
  end
  
rescue => e
  if Rails.env.test?
    # In test environment, create a mock kafka client
    Rails.logger.warn "Kafka not available during tests: #{e.message}"
    $kafka = Class.new do
      def deliver_message(message, topic:)
        Rails.logger.debug "Mock Kafka: would deliver '#{message}' to topic '#{topic}'"
      end
      
      def fetch_cluster_info
        # Mock method
      end
    end.new
  else
    # In other environments, re-raise the error
    raise e
  end
end

# Example method to produce a message
def produce_kafka_message(topic, message)
  $kafka.deliver_message(message, topic: topic)
end
