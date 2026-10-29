import 'package:true_compass/true_compass.dart';

/// A few synthetic example places for the demo (coordinates are public
/// geography, not user data).
class City {
  const City(this.name, this.location);

  final String name;
  final CompassLocation location;
}

const cities = <City>[
  City('Paris', CompassLocation(latitude: 48.8566, longitude: 2.3522)),
  City('Seattle', CompassLocation(latitude: 47.6062, longitude: -122.3321)),
  City('Sao Paulo', CompassLocation(latitude: -23.5505, longitude: -46.6333)),
  City('Mumbai', CompassLocation(latitude: 19.0760, longitude: 72.8777)),
  City('Sydney', CompassLocation(latitude: -33.8688, longitude: 151.2093)),
  City('Nairobi', CompassLocation(latitude: -1.2921, longitude: 36.8219)),
  City('Reykjavik', CompassLocation(latitude: 64.1466, longitude: -21.9426)),
];
