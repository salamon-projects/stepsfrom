# A verified attribute of a property, such as being on the waterfront. Each
# subclass (see app/models/verifications/) defines its categories, which of
# them are listed publicly, and what its evidence holds. A person reviews every
# result before it is shown.
class Verification < ApplicationRecord
  QA_STATUSES = %w[pending approved rejected].freeze
  CATEGORIES = %w[unknown].freeze
  LISTED_CATEGORIES = [].freeze

  belongs_to :property

  enum :qa_status, QA_STATUSES.index_by(&:itself), prefix: :qa, validate: true

  validates :type, uniqueness: { scope: %i[property_id subject] }
  validates :distance_m, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true

  # Approved results in a category that may be shown to visitors.
  def self.listed
    qa_approved.where(category: self::LISTED_CATEGORIES)
  end

  # Key used for translations and CSS, e.g. "waterfront".
  def self.key
    name.demodulize.underscore
  end

  def listed?
    qa_approved? && category.in?(self.class::LISTED_CATEGORIES)
  end
end
