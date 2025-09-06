# config/initializers/kafka.rb

require 'kafka'

$kafka = Kafka.new(
  seed_brokers: [ENV.fetch('KAFKA_BROKERS', 'localhost:9092')],
  client_id: 'myapp'
)

# Example method to produce a message
def produce_kafka_message(topic, message)
  $kafka.deliver_message(message, topic: topic)
end
