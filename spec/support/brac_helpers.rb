# Places for specs of Brač's non-rectangular area (create(:destination, :brac)),
# as [lat, lon]: on the island, and on the mainland Omiš Riviera inside the
# rectangle Brač used to have.
module BracHelpers
  PLACES = {
    # On the island.
    milna: [ 43.327, 16.443 ],
    supetar: [ 43.383, 16.548 ],
    postira: [ 43.378, 16.630 ],
    bol: [ 43.262, 16.655 ],
    pucisca: [ 43.348, 16.730 ],
    villa_artos: [ 43.2623, 16.7782 ],
    povlja: [ 43.340, 16.835 ],
    sumartin: [ 43.284, 16.877 ],
    # On the mainland.
    mala_luka: [ 43.4187, 16.7171 ],
    ujdur: [ 43.4199, 16.7140 ],
    sagitta: [ 43.4081, 16.7500 ],
    kennedy: [ 43.4042, 16.8139 ],
    andrea: [ 43.4016, 16.8385 ],
    pisak: [ 43.3989, 16.8652 ],
    derek: [ 43.3981, 16.8683 ]
  }.freeze

  ISLAND = %i[milna supetar postira bol pucisca villa_artos povlja sumartin].freeze
  MAINLAND = %i[mala_luka ujdur sagitta kennedy andrea pisak derek].freeze

  def brac_point(place)
    lat, lon = PLACES.fetch(place)
    Geo.point(lon:, lat:)
  end

  # A property measured direct beachfront at the place.
  def brac_property(place, **attributes)
    latitude, longitude = PLACES.fetch(place)
    create(:property, :direct, latitude:, longitude:, **attributes)
  end
end

RSpec.configure { |config| config.include BracHelpers }
