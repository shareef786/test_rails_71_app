# config/initializers/kafka.rb

require 'kafka'

# Kafka client wrapper that handles connection failures gracefully
class KafkaClientWrapper
  def initialize
    @real_client = nil
    @is_mock = false
    initialize_client
  end

  def deliver_message(message, topic:)
    if @is_mock
      Rails.logger.debug "Mock Kafka: would deliver '#{message}' to topic '#{topic}'"
    else
      @real_client.deliver_message(message, topic: topic)
    end
  end

  def fetch_cluster_info
    return {} if @is_mock
    @real_client.fetch_cluster_info
  end

  private

  def initialize_client
    if Rails.env.test?
      # Always use mock client in test environment
      @is_mock = true
      Rails.logger.info "Using mock Kafka client in test environment"
      return
    end

    begin
      @real_client = Kafka.new(
        seed_brokers: [ENV.fetch('KAFKA_BROKERS', 'localhost:9092')],
        client_id: 'myapp',
        connect_timeout: 1,
        socket_timeout: 1
      )
      
      # Test connection
      @real_client.fetch_cluster_info
      Rails.logger.info "Successfully connected to Kafka"
    rescue => e
      Rails.logger.warn "Kafka not available, using mock client: #{e.message}"
      @is_mock = true
      @real_client = nil
    end
  end
end

# Initialize the global Kafka client
$kafka = KafkaClientWrapper.new

# Example method to produce a message
def produce_kafka_message(topic, message)
  $kafka.deliver_message(message, topic: topic)
end
