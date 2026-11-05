# حالة مشروع سهل كاش

تاريخ التوثيق: 2026-11-02  
المرحلة الأخيرة المكتملة: الأمر السابع.  
حالة الاعتماد: الاعتماد النهائي ما زال معلقًا؛ هذا التقرير يحفظ الحالة فقط ولا يعتمد التعديلات.

## حدود العمل في هذا التوثيق

لم يُعدّل أي كود، ولم يُطبّق أي Migration، ولم يُشغّل التطبيق أو Hot Restart. لم تُنفّذ أي أوامر `INSERT` أو `UPDATE` أو `DELETE` على قاعدة التشغيل. فُحصت قاعدة التشغيل بفتح SQLite للقراءة فقط، وستُقارن بصمتها قبل النسخ وبعده في `BACKUP_REPORT.txt`.

## الملفات الموجودة عليها تغييرات قبل هذا التقرير

يعرض Git قبل إضافة هذا الملف 31 ملفًا معدلًا و17 ملفًا جديدًا غير متعقب:

### ملفات معدلة (31)

- `lib/data/repositories/invoice_repository.dart`
- `lib/database/database_helper.dart`
- `lib/models/invoice_model.dart`
- `lib/models/product_model.dart`
- `lib/models/product_sale_unit_model.dart`
- `lib/models/purchase_invoice_model.dart`
- `lib/models/receipt_voucher_model.dart`
- `lib/repositories/customer_repository.dart`
- `lib/repositories/product_repository.dart`
- `lib/repositories/purchase_invoice_repository.dart`
- `lib/repositories/receipt_voucher_repository.dart`
- `lib/screens/cashier/cashier_screen.dart`
- `lib/screens/customers/add_customer_dialog.dart`
- `lib/screens/customers/customer_statement_dialog.dart`
- `lib/screens/customers/receipt_voucher_dialog.dart`
- `lib/screens/inventory/inventory_screen.dart`
- `lib/screens/invoices/invoices_screen.dart`
- `lib/screens/products/add_product_dialog.dart`
- `lib/screens/products/conversion_manager_dialog.dart`
- `lib/screens/products/product_card.dart`
- `lib/screens/products/product_table.dart`
- `lib/screens/products/products_screen.dart`
- `lib/screens/products/units_manager.dart`
- `lib/screens/products/units_manager_dialog.dart`
- `lib/screens/profits/profits_screen.dart`
- `lib/screens/purchases/purchase_invoice_details_dialog.dart`
- `lib/screens/purchases/purchase_invoice_screen.dart`
- `lib/screens/purchases/purchase_invoices_list_screen.dart`
- `lib/screens/reports/reports_screen.dart`
- `lib/widgets/cashier_product_search_card.dart`
- `test/customer_credit_transaction_test.dart`

### ملفات جديدة غير متعقبة قبل هذا التقرير (17)

- `analyze_conversionToStorage.dart`
- `diagnose_bags.dart`
- `diagnose_bags_extended.dart`
- `diagnose_bags_final.dart`
- `diagnose_profits.dart`
- `diagnose_profits_simple.dart`
- `lib/models/customer_account_transaction_model.dart`
- `lib/models/inventory_movement_model.dart`
- `lib/utils/cashier_sale_unit_labels.dart`
- `lib/utils/product_cost_calculator.dart`
- `lib/utils/stock_quantity_converter.dart`
- `lib/utils/unit_name_normalizer.dart`
- `lib/widgets/product_sale_unit_selector.dart`
- `test/add_product_sale_unit_dialog_test.dart`
- `test/product_sale_unit_selector_and_cost_test.dart`
- `test/product_sale_unit_test.dart`
- `test/unit_master_table_test.dart`

هذا الملف هو إضافة توثيقية فقط؛ لا يتضمن تغييرات كود.

## الاختبارات والتحليلات

- `flutter test test\products_master_data_test.dart`: فشل اختباران من أصل خمسة، ونجحت ثلاثة. الفشلان هما `units manager supports add edit and delete` و`updating a unit name keeps conversion templates aligned`. أظهرت المخرجات أن القيمة المتوقعة `علبة` لم تظهر، مع خطأ عدم تهيئة Flutter ServicesBinding/PathProvider عند وصول الاختبار إلى قاعدة البيانات. لم يُحسم بعد إن كان الخلل من الاختبار أم التطبيق.
- `flutter analyze`: فشل رمز الخروج (1)، مع 0 أخطاء و6 تحذيرات و257 ملاحظة؛ المجموع 263.
- `git diff --check`: ناجح، رمز الخروج 0؛ ظهرت تنبيهات Git المعتادة حول تحويل LF إلى CRLF لبعض الملفات، دون أخطاء whitespace.
- لم تُشغّل بقية مجموعة الاختبارات في هذه المرحلة.

## إصدارات قواعد البيانات

- إصدار قاعدة البيانات في الكود: **25** (`version: 25` في `lib/database/database_helper.dart`).
- قاعدة التشغيل الفعلية: **22**؛ المسار المؤكد هو `C:\Users\IP\Documents\sahel_cash.db`.
- بيانات قاعدة التشغيل جُمعت للقراءة فقط عبر `PRAGMA user_version` وبيانات الملف:
  - الحجم: **98,304 بايت**.
  - آخر تعديل: **2026-11-02 04:57:39 +02:00**.
  - SHA-256: `144B7A41AECBA326E75287089ED92D43D48939879E42F0C36DDF30190D35F015`.
- لا تخلط بين قاعدة التشغيل وملف `C:\Projects\sahel_cash\sahel_cash.db` الموجود داخل المشروع: هذا الملف إصدار **14**، حجمه 73,728 بايت، وآخر تعديل `2026-10-02 01:18:39 +03:00`، وبصمته `1E4058BBACD2F21C44201316B71E976D61DF8A0BD03A0B7695E9EADFEFFECBF6`. لم يُستخدم بوصفه قاعدة التشغيل.

## النسخ الاحتياطية والبصمات

أُنشئ مجلد النسخة الكاملة الجديد خارج مجلد المشروع ودون استبدال أي نسخة سابقة:

- `C:\Projects\SahelCash_Backups\sahel_cash_snapshot_20261102_01`
- حُفظت نسخة ملف قاعدة التشغيل داخله باسم `runtime_sahel_cash_v22.db`.
- بدأ النسخ في `2026-11-02 12:39:52 +02:00`. اكتملت إعادة نسخ روابط Flutter في `12:42:20 +02:00`، ثم أُجريت مزامنة نهائية بعد اكتشاف ملفات Git أُنشئت لاحقًا؛ وقتها وعدد الملفات النهائيان موثقان في `BACKUP_REPORT.txt`.
- انتهت جولة Robocopy النهائية برمز 3 (نجاح مع نسخ ملفات ومجلدات) و0 ملفات أو مجلدات فاشلة. ظهرت في الجولة الأولى قيود Windows على روابط Flutter، ثم عولجت بجولة ثانية ناجحة دون حذف أي ملف.
- كشف التحقق الوسيط عن ملفات Git أُنشئت بعد جولة النسخ الأولى؛ نُسخت في المزامنة النهائية. يتضمن `BACKUP_REPORT.txt` بصمات الملفات المتحققة وعدد الملفات النهائي ونتيجة المطابقة الكاملة.
- نسخة قاعدة التشغيل المنفصلة: `C:\Projects\SahelCash_Backups\sahel_cash_snapshot_20261102_01\runtime_sahel_cash_v22.db`؛ بصمتها تطابق بصمة المصدر `144B7A41AECBA326E75287089ED92D43D48939879E42F0C36DDF30190D35F015`.
- تقرير `BACKUP_REPORT.txt` داخل مجلد النسخة يتضمن أعداد الملفات، وأوقات النسخ، وبصمات SHA-256، والتحقق من تطابق المصدر والنسخة.

بصمات الملفات المهمة قبل النسخ:

| الملف | SHA-256 |
|---|---|
| قاعدة التشغيل `C:\Users\IP\Documents\sahel_cash.db` (الإصدار 22) | `144B7A41AECBA326E75287089ED92D43D48939879E42F0C36DDF30190D35F015` |
| قاعدة المشروع `C:\Projects\sahel_cash\sahel_cash.db` (الإصدار 14) | `1E4058BBACD2F21C44201316B71E976D61DF8A0BD03A0B7695E9EADFEFFECBF6` |
| `lib/database/database_helper.dart` | `6A756777DCD3E7CA7C306A6314C507EA26EFB8E669D4827034D06AE6C7B82085` |
| `lib/repositories/receipt_voucher_repository.dart` | `68CAFE8DA5686904FF1C717FBB49D34EBF111757043C496E81A95CC7B01F2302` |
| `lib/data/repositories/invoice_repository.dart` | `92988E003ECDC5D94DF2DBC18E1338B73591779836D9218D450F1053F9871B1C` |
| `test/products_master_data_test.dart` | `D1129E223E045A94EAF9420BA5DAAF8BA87D0844AD85A4E35C6653B57EC32BF1` |

النسخ السابقة الموجودة قبل هذه المرحلة ستظل في أماكنها دون نقل أو حذف:

- `C:\Projects\SahelCash_Backups\sahel_cash_before_resume_20261102_070817`
- النسخ السابقة للملفات داخل `C:\Projects\SahelCash_Backups\lib` و`C:\Projects\SahelCash_Backups\test` (27 ملفًا؛ تفاصيل مساراتها وبصماتها في تقرير النسخ).
- قواعد البيانات الموجودة مسبقًا:
  - `C:\Projects\SahelCash_Backups\sahel_cash.db` — SHA-256: `6E86E40FAA5082F7FC28CA4A4D180B592C55A658648247C3EAFFC323E5D62BCD`
  - `C:\Projects\SahelCash_Backups\sahel_cash_database_20261102_071242.db` — SHA-256: `144B7A41AECBA326E75287089ED92D43D48939879E42F0C36DDF30190D35F015`
  - `C:\Projects\SahelCash_Backups\sahel_cash_pre_v22_20261102-032331.db` — SHA-256: `C3034D201ACD6142A6DFDF390B147E5CF5C3CFA932A67A30000B40FCC653E76B`
  - `C:\Users\IP\Documents\sahel_cash_pre_units_v22_20261102-0241.db` — SHA-256: `C3034D201ACD6142A6DFDF390B147E5CF5C3CFA932A67A30000B40FCC653E76B`
  - `C:\Users\IP\Documents\sahel_cash_backup_2026-10-13T19-41-05-081100.db` — SHA-256: `11680E54BC81252C173947517D36BF481CB914A830CA90E98A8EF050E59D8990`
  - `C:\Users\IP\Documents\sahel_cash_pre_nullable_sale_prices_20261101-190126.db` — SHA-256: `7F91A2F85A29010336518249C8A79E47132BBBBBEE84366ECB4B8EDD484FA282`

## مسائل لم تُحسم

- الفشلان في `products_master_data_test.dart`: تحديد ما إذا كان السبب الاختبار أم التطبيق.
- مراجعة مسارات تعديل وإلغاء إيصالات القبض والتأكد من عدم تجاوز دفتر حركات العميل.
- مراجعة Migration قاعدة البيانات 25 قبل تطبيقها على قاعدة التشغيل 22.
- إعادة التحقق من النسخ الاحتياطية وبصماتها.
- الاعتماد النهائي للأمر السابع ما زال معلقًا.

## نقاط الاستكمال المطلوبة

1. فحص فشل الاختبارين في `products_master_data_test.dart` وتحديد هل المشكلة في الاختبار أم في التطبيق.
2. مراجعة مسارات تعديل وإلغاء إيصالات القبض والتأكد من عدم وجود مسار يتجاوز دفتر حركات العميل.
3. مراجعة ترحيل قاعدة البيانات 25 قبل تطبيقه على قاعدة التشغيل.
4. إعادة التحقق من النسخ الاحتياطية وبصماتها.
