# sahel_cash

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## إنشاء قاعدة توزيع جديدة

أنشئ قاعدة بيانات جديدة في مسار غير موجود؛ ترفض الأداة استبدال أي ملف قائم:

```powershell
dart run tool/create_distribution_database.dart --output "C:\path\sahel_cash_distribution.db"
```

تنشئ القاعدة بالمخطط الحالي والوحدات القياسية فقط، دون مستخدمين أو منتجات أو
عملاء أو فواتير أو بيانات اختبار. عند أول تشغيل، يطلب التطبيق إنشاء حساب مدير
باسم مستخدم وكلمة مرور يختارهما المستخدم؛ لا توجد بيانات دخول افتراضية.
