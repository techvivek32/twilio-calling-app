import 'package:flutter/material.dart';

import '../core/countries.dart';
import '../core/theme.dart';

/// Compact country-code button; opens a searchable sheet when tapped.
class CountryCodeButton extends StatelessWidget {
  const CountryCodeButton({
    super.key,
    required this.country,
    required this.onChanged,
    this.enabled = true,
    this.dense = false,
  });

  final Country country;
  final ValueChanged<Country> onChanged;
  final bool enabled;
  final bool dense;

  Future<void> _open(BuildContext context) async {
    final picked = await showCountryPicker(context, selected: country);
    if (picked != null) onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceMuted,
      borderRadius: BorderRadius.circular(AppSpace.radiusField),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: enabled ? () => _open(context) : null,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: dense ? AppSpace.sm : AppSpace.md,
            vertical: dense ? 8 : AppSpace.md,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                country.flag,
                style: TextStyle(fontSize: dense ? 16 : 18),
              ),
              const SizedBox(width: 6),
              Text(
                country.plusCode,
                style: TextStyle(
                  fontSize: dense ? 15 : 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: 2),
              Icon(
                Icons.arrow_drop_down,
                size: dense ? 18 : 22,
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shows the country list and returns the chosen country, or null if dismissed.
Future<Country?> showCountryPicker(
  BuildContext context, {
  Country? selected,
}) {
  return showModalBottomSheet<Country>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _CountrySheet(selected: selected),
  );
}

class _CountrySheet extends StatefulWidget {
  const _CountrySheet({this.selected});

  final Country? selected;

  @override
  State<_CountrySheet> createState() => _CountrySheetState();
}

class _CountrySheetState extends State<_CountrySheet> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Country> get _filtered {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return kCountries;
    final bare = query.replaceFirst('+', '');
    return kCountries
        .where(
          (country) =>
              country.name.toLowerCase().contains(query) ||
              country.iso.toLowerCase() == query ||
              country.dialCode.startsWith(bare),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final results = _filtered;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.75,
        child: Column(
          children: [
            const SizedBox(height: AppSpace.md),
            Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(AppSpace.radiusPill),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpace.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Country code',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: AppSpace.md),
                  TextField(
                    controller: _searchController,
                    autofocus: true,
                    onChanged: (value) => setState(() => _query = value),
                    decoration: const InputDecoration(
                      hintText: 'Search country or code',
                      prefixIcon: Icon(Icons.search),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: results.isEmpty
                  ? const Center(
                      child: Text(
                        'No matching country.',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.only(bottom: AppSpace.xl),
                      itemCount: results.length,
                      separatorBuilder: (_, _) =>
                          const Divider(height: 1, indent: AppSpace.lg),
                      itemBuilder: (context, index) {
                        final country = results[index];
                        final isSelected =
                            widget.selected?.iso == country.iso;

                        return ListTile(
                          leading: Text(
                            country.flag,
                            style: const TextStyle(fontSize: 24),
                          ),
                          title: Text(
                            country.name,
                            style: TextStyle(
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                          ),
                          trailing: Text(
                            country.plusCode,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: isSelected
                                  ? AppColors.primary
                                  : AppColors.textSecondary,
                            ),
                          ),
                          selected: isSelected,
                          onTap: () => Navigator.of(context).pop(country),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
