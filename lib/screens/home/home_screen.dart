import 'package:flutter/material.dart';
import '../products/products_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  final List<Map<String, dynamic>> menuItems = const [
    {"title": "الكاشير", "icon": Icons.point_of_sale},
    {"title": "الأصناف", "icon": Icons.inventory_2},
    {"title": "العملاء", "icon": Icons.people},
    {"title": "الموردون", "icon": Icons.local_shipping},
    {"title": "الفواتير", "icon": Icons.receipt_long},
    {"title": "المصروفات", "icon": Icons.payments},
    {"title": "التقارير", "icon": Icons.bar_chart},
    {"title": "الأرباح", "icon": Icons.attach_money},
    {"title": "الإعدادات", "icon": Icons.settings},
    {"title": "المستخدمون", "icon": Icons.admin_panel_settings},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfff5f6fa),
      appBar: AppBar(
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        centerTitle: true,
        title: const Text(
          "سهل كاش",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: GridView.builder(
          itemCount: menuItems.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 20,
            mainAxisSpacing: 20,
            childAspectRatio: 1.2,
          ),
          itemBuilder: (context, index) {
            return Card(
              elevation: 5,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () {
                  if (menuItems[index]["title"] == "الأصناف") {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ProductsScreen(),
                      ),
                    );
                  }
                },
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      menuItems[index]["icon"],
                      size: 50,
                      color: Colors.indigo,
                    ),
                    const SizedBox(height: 15),
                    Text(
                      menuItems[index]["title"],
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}