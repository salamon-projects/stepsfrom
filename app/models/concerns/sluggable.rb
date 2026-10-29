# Generates a unique, URL-friendly slug from the name and uses it in URLs.
module Sluggable
  extend ActiveSupport::Concern

  included do
    before_validation :assign_slug, if: -> { slug.blank? && name.present? }
    validates :slug, presence: true, uniqueness: true,
      format: { with: /\A[a-z0-9]+(?:-[a-z0-9]+)*\z/ }
  end

  def to_param
    slug_was.presence || slug
  end

  private

  def assign_slug
    base = slug_base.parameterize.presence || self.class.model_name.singular
    candidate = base
    suffix = 2
    while self.class.where.not(id: id).exists?(slug: candidate)
      candidate = "#{base}-#{suffix}"
      suffix += 1
    end
    self.slug = candidate
  end

  def slug_base
    name
  end
end
