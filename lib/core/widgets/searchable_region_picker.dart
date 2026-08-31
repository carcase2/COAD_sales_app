import 'package:coad_customer_calls/core/widgets/search_highlight_text.dart';
import 'package:coad_customer_calls/models/master_data.dart';
import 'package:flutter/material.dart';

String regionPickerLabel(NamedMasterRow e) {
  final s = (e.extra['sido'] ?? '').trim();
  final r = (e.extra['region'] ?? '').trim();
  if (s.isNotEmpty && r.isNotEmpty && r != s) return '[$s]$r';
  if (s.isNotEmpty) return '[$s]';
  if (r.isNotEmpty) return r;
  return e.name;
}

class SearchableRegionPicker extends StatelessWidget {
  const SearchableRegionPicker({
    super.key,
    required this.regions,
    required this.value,
    required this.onChanged,
    this.validator,
    required this.decoration,
  });

  final List<NamedMasterRow> regions;
  final String? value;
  final void Function(String?) onChanged;
  final String? Function(String?)? validator;
  final InputDecoration decoration;

  @override
  Widget build(BuildContext context) {
    return FormField<String>(
      initialValue: value,
      validator: validator,
      builder: (FormFieldState<String> state) {
        final theme = Theme.of(context);

        String getSelectedDisplayValue(NamedMasterRow e) =>
            regionPickerLabel(e);

        String getListLabel(NamedMasterRow e) => regionPickerLabel(e);

        // Parent value takes precedence over FormField internal state if changed externally
        final currentValue = value ?? state.value;
        String currentLabel = '지역을 선택하세요';
        if (currentValue != null && currentValue.isNotEmpty) {
          try {
            final selectedRow = regions.firstWhere((e) => e.id == currentValue);
            currentLabel = getSelectedDisplayValue(selectedRow);
          } catch (_) {}
        }

        return InkWell(
          onTap: () async {
            final selectedId = await showModalBottomSheet<String>(
              context: context,
              isScrollControlled: true,
              useSafeArea: true,
              backgroundColor: theme.colorScheme.surface,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              builder: (ctx) => _RegionSearchBottomSheet(
                regions: regions,
                getListLabel: getListLabel,
                selectedValue: currentValue,
              ),
            );

            if (selectedId != null) {
              state.didChange(selectedId);
              onChanged(selectedId);
            }
          },
          borderRadius: BorderRadius.circular(16),
          child: InputDecorator(
            decoration: decoration.copyWith(errorText: state.errorText),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    currentLabel,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: currentValue == null
                          ? theme.colorScheme.onSurfaceVariant
                          : theme.colorScheme.onSurface,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _RegionSearchBottomSheet extends StatefulWidget {
  final List<NamedMasterRow> regions;
  final String Function(NamedMasterRow) getListLabel;
  final String? selectedValue;

  const _RegionSearchBottomSheet({
    required this.regions,
    required this.getListLabel,
    this.selectedValue,
  });

  @override
  State<_RegionSearchBottomSheet> createState() =>
      _RegionSearchBottomSheetState();
}

class _RegionSearchBottomSheetState extends State<_RegionSearchBottomSheet> {
  String _searchQuery = '';
  late List<NamedMasterRow> _filteredRegions;

  @override
  void initState() {
    super.initState();
    _filteredRegions = widget.regions;
  }

  void _onSearch(String query) {
    setState(() {
      _searchQuery = query;
      if (query.isEmpty) {
        _filteredRegions = widget.regions;
      } else {
        final terms = query.toLowerCase().split(' ').where((t) => t.isNotEmpty);
        _filteredRegions = widget.regions.where((r) {
          final displayName = widget.getListLabel(r).toLowerCase();
          final fullSearchText =
              '${r.extra['sido'] ?? ''} ${r.extra['region'] ?? ''} ${r.name}'
                  .toLowerCase();
          return terms.every(
            (term) =>
                fullSearchText.contains(term) || displayName.contains(term),
          );
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            // Grabber
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: scheme.onSurfaceVariant.withOpacity(0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 16, 12),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      '지역 선택',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: TextField(
                autofocus: true,
                decoration: InputDecoration(
                  hintText: '시/도, 지역명 검색...',
                  prefixIcon: Icon(Icons.search_rounded, color: scheme.primary),
                  filled: true,
                  fillColor: scheme.surfaceContainerHighest.withOpacity(0.3),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 16),
                ),
                style: const TextStyle(fontSize: 16),
                onChanged: _onSearch,
              ),
            ),
            const SizedBox(height: 8),
            const Divider(height: 1),
            Expanded(
              child: _filteredRegions.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.search_off_rounded,
                            size: 48,
                            color: scheme.outlineVariant,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '해당하는 지역이 없습니다.',
                            style: TextStyle(color: scheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.only(bottom: 24),
                      itemCount: _filteredRegions.length,
                      itemBuilder: (context, index) {
                        final r = _filteredRegions[index];
                        final listLabel = widget.getListLabel(r);
                        final isSelected = r.id == widget.selectedValue;

                        // For displaying selected manager below the name in the list, if requested
                        // but user requested not to show manager in the list.

                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 4,
                          ),
                          title: SearchHighlightText(
                            text: listLabel,
                            query: _searchQuery,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: isSelected
                                  ? FontWeight.w800
                                  : FontWeight.w500,
                              color: isSelected
                                  ? scheme.primary
                                  : scheme.onSurface,
                            ),
                          ),
                          trailing: isSelected
                              ? Icon(
                                  Icons.check_circle_rounded,
                                  color: scheme.primary,
                                )
                              : null,
                          tileColor: isSelected
                              ? scheme.primaryContainer.withOpacity(0.3)
                              : null,
                          onTap: () => Navigator.pop(context, r.id),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}
