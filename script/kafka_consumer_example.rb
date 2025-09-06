# Usage example for KafkaConsumerService
# You can run this script with: rails runner script/kafka_consumer_example.rb

# No need for require_relative since KafkaConsumerService is in app/services and will be autoloaded

topic = 'books'
group_id = 'books-consumer-group'

puts "Starting Kafka consumer for topic: #{topic}"
KafkaConsumerService.consume(topic, group_id)
