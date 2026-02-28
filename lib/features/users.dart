import 'package:academic_affairs_management/features/desktop_pages/add_user_dialog.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:academic_affairs_management/core/theme/desktop_theme.dart';

class Users extends StatelessWidget {
  const Users({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DesktopColors.background,
      appBar: _buildAppBar(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(DesktopSpacing.md),
        child: Column(
          children: [
            _buildHeader(),
            const SizedBox(height: DesktopSpacing.lg),
            _buildFiltersAndActions(
                context), // تمرير context لاستخدام النافذة المنبثقة لاحقاً
            const SizedBox(height: DesktopSpacing.md),
            _buildUsersTableStream(), // تم تغيير الدالة هنا لاستخدام Stream
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: Row(
        children: [
          const Icon(Icons.school, color: DesktopColors.primary),
          const SizedBox(width: DesktopSpacing.xs),
          Text('النيابة العامة',
              style:
                  DesktopTextStyles.body.copyWith(fontWeight: FontWeight.bold)),
        ],
      ),
      actions: [
        TextButton(onPressed: () {}, child: const Text('العربية | EN')),
        IconButton(
            icon: const Icon(Icons.notifications_none), onPressed: () {}),
        IconButton(icon: const Icon(Icons.settings_outlined), onPressed: () {}),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.0),
          child: CircleAvatar(
              backgroundColor: Color.fromARGB(255, 219, 215, 220),
              child: Text('أ')),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('إدارة المستخدمين والصلاحيات',
                style: DesktopTextStyles.heading1),
            const SizedBox(height: DesktopSpacing.xs / 2),
            Text(
              'إضافة المستخدمين وتعيين صلاحياتهم وأدوارهم في النظام',
              style: DesktopTextStyles.caption,
            ),
            const SizedBox(height: DesktopSpacing.xs),
          ],
        ),
      ],
    );
  }

  Widget _buildFiltersAndActions(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              flex: 3,
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'ابحث بالاسم، الرقم الوظيفي، البريد، الكلية...',
                  prefixIcon: const Icon(Icons.search),
                  enabledBorder:
                      DesktopInputTheme.inputDecorationTheme.enabledBorder,
                  focusedBorder:
                      DesktopInputTheme.inputDecorationTheme.focusedBorder,
                ),
              ),
            ),
            const SizedBox(width: DesktopSpacing.xs),
            ElevatedButton(
              onPressed: () {
                showDialog(
                  context: context,
                  barrierDismissible: false, 
                  builder: (context) => const AddUserDialog(),
                );
              },
              style: DesktopButtonTheme.elevatedButtonTheme.style,
              child: Row(
                children: [
                  Icon(
                    Icons.add,
                    color: DesktopColors.surface,
                  ),
                  Text(
                    'أضافة مستخدم جديد',
                  )
                ],
              ),
            )
          ],
        ),
        const SizedBox(height: DesktopSpacing.sm),
        Row(
          children: [
            _buildDropdownFilter('كل الكليات'),
            const SizedBox(width: 10),
            _buildDropdownFilter('كل الأقسام'),
            const SizedBox(width: 10),
            _buildDropdownFilter('كل المستويات'),
            const SizedBox(width: 10),
            _buildDropdownFilter('كل الحالات'),
            const SizedBox(width: 10),
            TextButton(
              onPressed: () {},
              child: const Text('مسح المرشحات',
                  style: TextStyle(color: DesktopColors.primary)),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDropdownFilter(String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: DesktopSpacing.xs + 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: DesktopColors.border),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            hint: Text(label, style: DesktopTextStyles.caption),
            isExpanded: true,
            items: const [],
            onChanged: (val) {},
          ),
        ),
      ),
    );
  }

  // 4. جدول البيانات المربوط بـ Firestore (Data Table Stream)
  Widget _buildUsersTableStream() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: DesktopColors.border),
      ),
      child: StreamBuilder<QuerySnapshot>(
        // الاستماع للتغييرات في كولكشن 'users'
        stream: FirebaseFirestore.instance.collection('users').snapshots(),
        builder: (context, snapshot) {
          // حالة التحميل
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: Padding(
              padding: EdgeInsets.all(DesktopSpacing.lg),
              child: CircularProgressIndicator(),
            ));
          }

          // حالة الخطأ
          if (snapshot.hasError) {
            return Center(child: Text('حدث خطأ: ${snapshot.error}'));
          }

          // حالة عدم وجود بيانات
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
                child: Padding(
              padding: EdgeInsets.all(DesktopSpacing.lg),
              child: Text('لا يوجد مستخدمين مسجلين حالياً'),
            ));
          }

          // بناء الجدول عند توفر البيانات
          final users = snapshot.data!.docs;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DataTable(
                headingRowColor:
                    WidgetStatePropertyAll(DesktopColors.background),
                horizontalMargin: DesktopSpacing.xs,
                columnSpacing:
                    DesktopSpacing.sm, // تم تقليل المسافة لتناسب العرض
                columns: const [
                  DataColumn(
                      label: Text('المعرف',
                          style: DesktopTextStyles
                              .caption)), // بدلاً من Checkbox مؤقتاً
                  DataColumn(
                      label: Text(
                    'الاسم',
                    style: DesktopTextStyles.caption,
                  )),
                  DataColumn(
                      label: Text('البريد الإلكتروني',
                          style: DesktopTextStyles.caption)),
                  DataColumn(
                      label: Text('الدور', style: DesktopTextStyles.caption)),
                  DataColumn(
                      label: Text('تاريخ الإنشاء',
                          style: DesktopTextStyles.caption)),
                  DataColumn(
                      label: Text('إجراءات', style: DesktopTextStyles.caption)),
                ],
                rows: users.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  // معالجة البيانات بأمان (تجنب القيم الفارغة null)
                  final name = data['name'] ?? 'غير معروف';
                  final email = data['email'] ?? 'غير معروف';
                  final role = data['role'] ?? 'غير محدد';
                  final createdAtTimestamp = data['createAt'] as Timestamp?;
                  final createdAt = createdAtTimestamp != null
                      ? createdAtTimestamp.toDate().toString().split(' ')[0]
                      : '-';

                  return DataRow(cells: [
                    // عرض أول 5 حروف من الـ ID كمعرف مختصر
                    DataCell(Text('#${doc.id.substring(0, 5)}...',
                        style: DesktopTextStyles.caption)),
                    DataCell(Text(name, style: DesktopTextStyles.body)),
                    DataCell(Text(email, style: DesktopTextStyles.body)),
                    DataCell(_buildRoleBadge(role)), // دالة مساعدة لتلوين الدور
                    DataCell(Text(createdAt, style: DesktopTextStyles.caption)),
                    DataCell(
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert, color: Colors.grey),
                        onSelected: (value) {
                          // هنا تضع أكواد الحذف أو التعديل
                          if (value == 'delete') {
                            _deleteUser(doc.id);
                          }
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'delete',
                            child: Row(children: [
                              Icon(Icons.delete,
                                  color: Colors.red, size: DesktopSpacing.sm),
                              SizedBox(width: DesktopSpacing.xs),
                              Text('حذف', style: TextStyle(color: Colors.red))
                            ]),
                          ),
                        ],
                      ),
                    ),
                  ]);
                }).toList(),
              ),
            ],
          );
        },
      ),
    );
  }

  // دالة مساعدة لحذف المستخدم (للتوضيح)
  Future<void> _deleteUser(String userId) async {
    await FirebaseFirestore.instance.collection('users').doc(userId).delete();
  }

  // تصميم الشارة للدور (Role Badge)
  Widget _buildRoleBadge(String role) {
    Color color;
    switch (role) {
      case 'super_admin':
        color = Colors.red;
        break;
      case 'Public Prosecution':
        color = Colors.blue;
        break;
      case 'Deputy Dean':
        color = Colors.green;
        break;
      case 'Head of department':
        color = Colors.yellow;
        break;
      default:
        color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: DesktopSpacing.xs, vertical: DesktopSpacing.xs / 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        role,
        style:
            TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold),
      ),
    );
  }
}
