class KafkaConsumerService
  def self.consume(topic, group_id = 'myapp-consumer-group')
    consumer = $kafka.consumer(group_id: group_id)
    consumer.subscribe(topic)
    consumer.each_message do |message|
      puts "Received message: \\#{message.value}"
      # Add your message processing logic here
    end
  end
end
