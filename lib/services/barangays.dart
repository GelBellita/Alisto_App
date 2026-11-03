// =========================================================
// BARANGAYS — Dart copy of the web's barangays.py.
//
// A BHW only sees an elder when the elder's address contains the BHW's
// barangay_assigned, so the app must save the SAME spelling the web
// dropdown uses. canonicalBarangay() also tolerates older typed values
// ("Sudlon 2", "Brgy. Sudlon II") exactly like the web's canonical().
// =========================================================

const List<String> kCebuCityBarangays = [
  'Adlaon', 'Agsungot', 'Apas', 'Babag', 'Bacayan', 'Banilad', 'Basak Pardo',
  'Basak San Nicolas', 'Binaliw', 'Bonbon', 'Budla-an', 'Buhisan', 'Bulacao',
  'Buot-Taup Pardo', 'Busay', 'Calamba', 'Cambinocot', 'Camputhaw',
  'Capitol Site', 'Carreta', 'Central', 'Cogon Pardo', 'Cogon Ramos',
  'Day-as', 'Duljo', 'Ermita', 'Guadalupe', 'Guba', 'Hippodromo', 'Inayawan',
  'Kalubihan', 'Kalunasan', 'Kamagayan', 'Kasambagan', 'Kinasang-an Pardo',
  'Labangon', 'Lahug', 'Lorega (Lorega San Miguel)', 'Lusaran', 'Luz',
  'Mabini', 'Mabolo', 'Malubog', 'Mambaling', 'Pahina Central',
  'Pahina San Nicolas', 'Pamutan', 'Pardo', 'Pari-an', 'Paril', 'Pasil',
  'Pit-os', 'Pulangbato', 'Pung-ol-Sibugay', 'Punta Princesa', 'Quiot Pardo',
  'Sambag I', 'Sambag II', 'San Antonio', 'San Jose', 'San Nicolas Central',
  'San Roque (Ciudad)', 'Santa Cruz', 'Sapangdaku', 'Sawang Calero', 'Sinsin',
  'Sirao', 'Suba Pob. (Suba San Nicolas)', 'Sudlon I', 'Sudlon II',
  'T. Padilla', 'Tabunan', 'Tagbao', 'Talamban', 'Taptap',
  'Tejero (Villa Gonzalo)', 'Tinago', 'Tisa', 'To-ong Pardo', 'Zapatera',
];

const Map<String, String> _roman = {
  '1': 'i', '2': 'ii', '3': 'iii', '4': 'iv', '5': 'v',
};

/// Loose comparison key: 'Brgy. Sudlon 2' -> 'sudlon ii' (same as _key()).
String _key(String? text) {
  var s = (text ?? '').toLowerCase();
  s = s.replaceAll(RegExp(r'\b(barangay|brgy|bgy)\b\.?'), ' ');
  s = s.replaceAll(RegExp(r'\b(pob|poblacion)\b\.?'), ' ');
  s = s.replaceAll(RegExp(r'[^a-z0-9]+'), ' ');
  s = s.replaceAllMapped(
    RegExp(r'\b([1-5])\b'),
    (m) => _roman[m.group(1)!]!,
  );
  return s.split(' ').where((p) => p.isNotEmpty).join(' ');
}

final Map<String, String> _index = () {
  final index = <String, String>{};
  for (final name in kCebuCityBarangays) {
    final main = name.replaceAll(RegExp(r'\(.*?\)'), ' ');
    final inner =
        RegExp(r'\((.*?)\)').allMatches(name).map((m) => m.group(1)!);
    for (final variant in [name, main, ...inner]) {
      index.putIfAbsent(_key(variant), () => name);
    }
  }
  return index;
}();

/// The dropdown spelling for [text], or null if it isn't a Cebu City barangay.
String? canonicalBarangay(String? text) => _index[_key(text)];

/// The address as a list of parts, whatever shape it was stored in
/// (bhw_routes.py's _address_parts()).
List<String> addressParts(dynamic address) {
  if (address == null) return const [];
  if (address is String) {
    return address
        .split(',')
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();
  }
  if (address is Map) {
    const order = [
      'house_no', 'house_number', 'unit', 'street', 'purok', 'barangay',
      'city', 'municipality', 'province', 'zip_code', 'zip',
    ];
    return [
      for (final k in order)
        if ((address[k] ?? '').toString().trim().isNotEmpty)
          address[k].toString().trim(),
    ];
  }
  return const [];
}
