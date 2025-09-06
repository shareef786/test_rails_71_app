# config/initializers/disable_elasticsearch_in_tests.rb

if Rails.env.test?
  # Completely disable Elasticsearch callbacks in test environment
  Rails.application.config.after_initialize do
    begin
      if defined?(Book) && defined?(Elasticsearch::Model::Callbacks)
        # Override the callback methods to do nothing in test environment
        Book.class_eval do
          def __elasticsearch__
            # Return a mock object that responds to index, update, and delete
            @mock_elasticsearch ||= Class.new do
              def index_document; end
              def update_document; end
              def delete_document; end
            end.new
          end
        end
        
        Rails.logger.info "Disabled Elasticsearch callbacks for Book model in test environment"
      end
    rescue => e
      Rails.logger.warn "Could not disable Elasticsearch callbacks: #{e.message}"
    end
  end
end
