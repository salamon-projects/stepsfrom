# Places for specs of Kassandra's non-rectangular area
# (create(:destination, :kassandra)), as [lat, lon].
module KassandraHelpers
  PLACES = {
    # On the Kassandra peninsula.
    kallithea: [ 40.070, 23.450 ],
    istion_club: [ 40.213, 23.319 ],
    # On Sithonia, inside the rectangle Kassandra used to have.
    porto_carras: [ 40.074, 23.795 ],
    vourvourou: [ 40.187, 23.793 ],
    # On Sithonia, inside even the peninsula's bounding box.
    anthemus_sea: [ 40.145, 23.735 ]
  }.freeze

  def kassandra_point(place)
    lat, lon = PLACES.fetch(place)
    Geo.point(lon:, lat:)
  end

  # A property measured direct beachfront at the place.
  def kassandra_property(place, **attributes)
    latitude, longitude = PLACES.fetch(place)
    create(:property, :direct, latitude:, longitude:, **attributes)
  end
end

RSpec.configure { |config| config.include KassandraHelpers }
