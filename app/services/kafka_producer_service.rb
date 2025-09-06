class KafkaProducerService
  def self.publish(topic, message)
    $kafka.deliver_message(message, topic: topic)
  end
end
