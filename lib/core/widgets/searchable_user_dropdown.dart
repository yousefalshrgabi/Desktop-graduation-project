import 'package:flutter/material.dart';
import 'package:academic_affairs_management/core/theme/desktop_theme.dart';

class SearchableUserDropdown extends StatelessWidget {
  final String? value;
  final String? initialName;
  final String hint;
  final List<Map<String, dynamic>> items;
  final void Function(String?) onChanged;
  final String? defaultName;

  const SearchableUserDropdown({
    super.key,
    required this.value,
    this.initialName,
    required this.hint,
    required this.items,
    required this.onChanged,
    this.defaultName,
  });

  @override
  Widget build(BuildContext context) {
    // التحقق من القيمة الحالية
    final Map<String, dynamic> initialUser = items.cast<Map<String, dynamic>>().firstWhere(
      (u) => u['id'] == value,
      orElse: () => <String, dynamic>{'name': defaultName ?? '', 'id': null},
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        return Autocomplete<Map<String, dynamic>>(
          optionsBuilder: (TextEditingValue textEditingValue) {
            final allItems = [
              {'id': null, 'name': defaultName ?? 'لا يوجد (غير محدد)'},
              ...items,
            ];
            if (textEditingValue.text.isEmpty) {
              return allItems;
            }
            return allItems.where((Map<String, dynamic> option) {
              return option['name']
                  .toString()
                  .toLowerCase()
                  .contains(textEditingValue.text.toLowerCase());
            });
          },
          displayStringForOption: (option) => option['name'] ?? '',
          onSelected: (Map<String, dynamic> selection) {
            onChanged(selection['id']);
          },
          initialValue: TextEditingValue(
            text: (initialName != null && initialName!.isNotEmpty)
                ? initialName!
                : (initialUser['name'] ?? ''),
          ),
          fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
            return TextFormField(
              controller: controller,
              focusNode: focusNode,
              decoration: InputDecoration(
                hintText: hint,
                prefixIcon: const Icon(Icons.person, color: Colors.grey),
                suffixIcon:
                    const Icon(Icons.arrow_drop_down, color: Colors.grey),
                filled: true,
                fillColor: Colors.grey[50],
                enabledBorder:
                    DesktopInputTheme.inputDecorationTheme.enabledBorder,
                focusedBorder:
                    DesktopInputTheme.inputDecorationTheme.focusedBorder,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            );
          },
          optionsViewBuilder: (context, onSelected, options) {
            return Align(
              alignment: Alignment.topRight, // المحاذاة لليمين لأن التطبيق عربي
              child: Padding(
                padding:
                    const EdgeInsets.only(top: 4.0), // مسافة بسيطة أسفل الحقل
                child: Material(
                  elevation: 8,
                  borderRadius: BorderRadius.circular(8),
                  clipBehavior: Clip.antiAlias,
                  child: Container(
                    width: constraints.maxWidth,
                    constraints: const BoxConstraints(maxHeight: 250),
                    color: Colors.white,
                    child: ListView.separated(
                      padding: EdgeInsets.zero,
                      shrinkWrap: true,
                      itemCount: options.length,
                      separatorBuilder: (context, index) =>
                          const Divider(height: 1, color: Color(0xFFEEEEEE)),
                      itemBuilder: (BuildContext context, int index) {
                        final Map<String, dynamic> option =
                            options.elementAt(index);
                        return ListTile(
                          title: Text(option['name'] ?? '',
                              style: DesktopTextStyles.body),
                          hoverColor: DesktopColors.primary.withOpacity(0.1),
                          onTap: () => onSelected(option),
                        );
                      },
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
