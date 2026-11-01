# Dates and party size a visitor searches for.
class Stay
  include ActiveModel::Model
  include ActiveModel::Attributes

  MAX_NIGHTS = 30
  MAX_ADULTS = 8
  MAX_CHILDREN = 6
  CHILD_AGES = (0..17)
  PARAM_KEYS = [ :check_in, :check_out, :adults, :children, { child_ages: [] } ].freeze

  attribute :check_in, :date
  attribute :check_out, :date
  attribute :adults, :integer, default: 2
  attribute :children, :integer, default: 0
  # One age per child, as booking sites ask for them.
  attribute :child_ages, default: -> { [] }

  validates :check_in, :check_out, presence: true
  validates :adults, numericality: { only_integer: true, in: 1..MAX_ADULTS }
  validates :children, numericality: { only_integer: true, in: 0..MAX_CHILDREN }
  validate :dates_are_sensible
  validate :child_ages_given

  # Returns nil when the visitor did not enter dates.
  def self.from_params(params)
    keys = PARAM_KEYS.map { |key| key.is_a?(Hash) ? key.keys.first : key }
    # Slice before permitting so other request params (route :id, filters)
    # are not logged as unpermitted.
    attrs = params.respond_to?(:permit) ? params.slice(*keys).permit(*PARAM_KEYS).to_h : params.to_h
    attrs = attrs.symbolize_keys.slice(*keys)
    return if attrs[:check_in].blank? && attrs[:check_out].blank?

    attrs.delete(:adults) if attrs[:adults].blank?
    attrs.delete(:children) if attrs[:children].blank?
    # The form always sends an age field per possible child; only the
    # first `children` of them count.
    children = attrs[:children].to_i
    attrs[:child_ages] = Array(attrs[:child_ages]).first(children).map { |age| Integer(age, exception: false) }
    new(attrs)
  rescue ArgumentError
    nil
  end

  def nights
    (check_out - check_in).to_i
  end

  def to_params
    params = { check_in: check_in&.iso8601, check_out: check_out&.iso8601, adults: adults }
    params.merge!(children: children, child_ages: child_ages) if children.to_i.positive?
    params
  end

  private

  def dates_are_sensible
    return if check_in.blank? || check_out.blank?

    errors.add(:check_in, :in_the_past) if check_in < Date.current
    errors.add(:check_out, :before_check_in) unless check_out > check_in
    errors.add(:check_out, :too_long, count: MAX_NIGHTS) if nights > MAX_NIGHTS
  end

  def child_ages_given
    return unless children.is_a?(Integer)

    ages = Array(child_ages)
    errors.add(:child_ages, :missing) unless ages.size == children && ages.all? { |age| CHILD_AGES.cover?(age) }
  end
end
