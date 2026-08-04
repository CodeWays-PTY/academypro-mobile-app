import 'package:flutter/material.dart';

class CountryCode {
  final String name;
  final String dialCode;
  final String flag;
  final String code;

  const CountryCode({
    required this.name,
    required this.dialCode,
    required this.flag,
    required this.code,
  });
}

class CountryCodePicker {
  static const List<CountryCode> defaultCountries = [
    CountryCode(name: 'South Africa', dialCode: '+27', flag: '🇿🇦', code: 'ZA'),
    CountryCode(name: 'Namibia', dialCode: '+264', flag: '🇳🇦', code: 'NA'),
    CountryCode(name: 'Zimbabwe', dialCode: '+263', flag: '🇿🇼', code: 'ZW'),
    CountryCode(name: 'Botswana', dialCode: '+267', flag: '🇧🇼', code: 'BW'),
    CountryCode(name: 'Mozambique', dialCode: '+258', flag: '🇲🇿', code: 'MZ'),
    CountryCode(name: 'Zambia', dialCode: '+260', flag: '🇿🇲', code: 'ZM'),
    CountryCode(name: 'United Kingdom', dialCode: '+44', flag: '🇬🇧', code: 'GB'),
    CountryCode(name: 'United States', dialCode: '+1', flag: '🇺🇸', code: 'US'),
    CountryCode(name: 'Australia', dialCode: '+61', flag: '🇦🇺', code: 'AU'),
    CountryCode(name: 'New Zealand', dialCode: '+64', flag: '🇳🇿', code: 'NZ'),
  ];

  static void show(BuildContext context, {required ValueChanged<CountryCode> onSelected}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.0)),
      ),
      builder: (context) {
        String searchQuery = '';
        return StatefulBuilder(
          builder: (context, setModalState) {
            final filtered = defaultCountries.where((c) {
              final query = searchQuery.toLowerCase();
              return c.name.toLowerCase().contains(query) || c.dialCode.contains(query);
            }).toList();

            return Padding(
              padding: EdgeInsets.only(
                left: 20.0,
                right: 20.0,
                top: 20.0,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20.0,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36.0,
                      height: 4.0,
                      decoration: BoxDecoration(
                        color: const Color(0xFFCBD5E1),
                        borderRadius: BorderRadius.circular(2.0),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16.0),
                  const Text(
                    'Select Country Code',
                    style: TextStyle(fontSize: 18.0, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                  const SizedBox(height: 12.0),
                  TextField(
                    onChanged: (val) => setModalState(() => searchQuery = val),
                    decoration: InputDecoration(
                      hintText: 'Search country or dial code (e.g. +27)',
                      prefixIcon: const Icon(Icons.search, color: Color(0xFF64748B)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.0)),
                    ),
                  ),
                  const SizedBox(height: 16.0),
                  ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.40),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: filtered.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final item = filtered[index];
                        return ListTile(
                          leading: Text(item.flag, style: const TextStyle(fontSize: 24.0)),
                          title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.0)),
                          trailing: Text(
                            item.dialCode,
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF003EC7), fontSize: 14.0),
                          ),
                          onTap: () {
                            onSelected(item);
                            Navigator.pop(context);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
