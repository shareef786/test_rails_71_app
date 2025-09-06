
class Book < ApplicationRecord
	# TEMPORARILY COMMENTED OUT FOR TESTING
	# include Elasticsearch::Model
	# include Elasticsearch::Model::Callbacks

	# # You can customize the Elasticsearch index settings and mappings here if needed
	# settings index: { number_of_shards: 1 } do
	#   mappings dynamic: false do
	#     indexes :title, type: :text
	#     indexes :author, type: :text
	#     indexes :published_on, type: :date
	#   end
	# end
end
