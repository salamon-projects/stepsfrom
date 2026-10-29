# Dates and party size a visitor searches for.
class Stay
  include ActiveModel::Model
  include ActiveModel::Attributes

  MAX_NIGHTS = 30
  MAX_ADULTS = 8

  attribute :check_in, :date
  attribute :check_out, :date
  attribute :adults, :integer, default: 2

  validates :check_in, :check_out, presence: true
  validates :adults, numericality: { only_integer: true, in: 1..MAX_ADULTS }
  validate :dates_are_sensible

  # Returns nil when the visitor did not enter dates.
  def self.from_params(params)
    attrs = params.respond_to?(:permit) ? params.permit(:check_in, :check_out, :adults).to_h : params.to_h
    attrs = attrs.symbolize_keys.slice(:check_in, :check_out, :adults)
    return if attrs[:check_in].blank? && attrs[:check_out].blank?

    attrs.delete(:adults) if attrs[:adults].blank?
    new(attrs)
  rescue ArgumentError
    nil
  end

  def nights
    (check_out - check_in).to_i
  end

  def to_params
    { check_in: check_in&.iso8601, check_out: check_out&.iso8601, adults: adults }
  end

  private

  def dates_are_sensible
    return if check_in.blank? || check_out.blank?

    errors.add(:check_in, :in_the_past) if check_in < Date.current
    errors.add(:check_out, :before_check_in) unless check_out > check_in
    errors.add(:check_out, :too_long, count: MAX_NIGHTS) if nights > MAX_NIGHTS
  end
end
