class KafkaProducerService
  def self.publish(topic, message)
    begin
      $kafka.deliver_message(message, topic: topic)
    rescue => e
      Rails.logger.error "Failed to publish Kafka message: #{e.message}"
      # In test/development, just log and continue
      raise e unless Rails.env.test? || Rails.env.development?
    end
  end
end
