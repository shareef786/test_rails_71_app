class KafkaProducerService
  def self.publish(topic, message)
    # TEMPORARILY COMMENTED OUT FOR TESTING
    # $kafka.deliver_message(message, topic: topic)
    Rails.logger.debug "Mock KafkaProducerService: would publish '#{message}' to topic '#{topic}'"
  end
end
