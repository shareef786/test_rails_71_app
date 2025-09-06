# Usage example for KafkaConsumerService
# You can run this script with: rails runner app/services/kafka_consumer_example.rb

require_relative 'kafka_consumer_service'

topic = 'books'
group_id = 'books-consumer-group'

puts "Starting Kafka consumer for topic: #{topic}"
KafkaConsumerService.consume(topic, group_id)
