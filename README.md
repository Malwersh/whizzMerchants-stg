# WhizzMerchants Staging Environment

نسخة staging نظيفة من تطبيق WhizzMerchants (Restaurant/Merchant App)

## 📊 المعلومات الأساسية

- **الحجم:** 43 MB (مقارنة بـ 1.1 GB في النسخة الأصلية - تقليل 96%)
- **تاريخ الإنشاء:** 29 ديسمبر 2024
- **الهدف:** بيئة staging معزولة بالكامل للاختبار الآمن

## 🗂️ البنية

```
whizzMerchants-stg/
├── frontend/          # تطبيق Flutter للمطاعم
│   ├── lib/           # 187 ملف Dart
│   ├── android/       # تكوين Android
│   ├── ios/          # تكوين iOS
│   ├── assets/       # الصور والأيقونات
│   └── pubspec.yaml  # Dependencies
└── backend/           # Lambda Functions & APIs
    ├── functions/     # 38 Lambda function
    ├── api/          # OpenAPI specs
    ├── template.yaml  # SAM template
    └── samconfig.toml # SAM config
```

## ✨ مميزات التطبيق

### Frontend Features (187 Dart Files)

#### 🏪 Restaurant Management
- Product catalog management
- Category organization
- Inventory tracking
- Menu updates
- Pricing management

#### 📱 Order Management
- Real-time order notifications
- Order acceptance/rejection
- Order status updates
- Order history
- Multi-order handling

#### 🔔 Real-time Updates
- WebSocket integration
- Push notifications
- Order alerts
- Status change notifications

#### 👤 Business Profile
- Restaurant information
- Operating hours
- Location management
- Contact details
- Business verification

#### 📊 Analytics & Reports
- Sales reports
- Order statistics
- Revenue tracking
- Performance metrics

#### 🎨 UI Components
- Arabic RTL support
- Material Design
- Custom widgets
- Theme management

### Backend Services (38 Lambda Functions)

#### Authentication & Authorization
- Business login/registration
- Token management
- Session handling
- RBAC implementation

#### Order Processing
- Order creation
- Status updates
- Order acceptance/rejection
- Order notifications
- Order history

#### Product Management
- Product CRUD operations
- Category management
- Inventory updates
- Price management
- Product search

#### WebSocket Services
- Connection management
- Real-time broadcasting
- Order notifications
- Status updates
- Business app connections

#### Payment & Wallet
- Transaction processing
- Balance management
- Payout handling

#### Notifications
- Push notifications
- Email notifications
- SMS notifications
- In-app notifications

## 🚀 التثبيت والتشغيل

### Frontend Setup

```bash
cd whizzMerchants-stg/frontend

# تثبيت Dependencies
flutter pub get

# تشغيل على iOS
flutter run

# بناء للإنتاج
flutter build ios --release
flutter build apk --release
```

### Backend Setup

```bash
cd whizzMerchants-stg/backend

# تثبيت Dependencies (إذا لزم الأمر)
npm install  # في كل دليل function يحتوي على package.json

# بناء Lambda Functions
sam build

# نشر على AWS (staging)
sam deploy --config-env staging
```

## 🔧 التكوين المطلوب

### AWS Resources Needed

#### Cognito
- **User Pool:** WhizzMerchants-Staging
- **Purpose:** Business authentication
- **Attributes:** email, phone, business_id

#### Lambda Functions
- All 38 functions with `-staging` suffix
- Node.js runtime
- Appropriate IAM roles

#### API Gateway
- REST API: merchants-api-staging
- WebSocket API: merchants-ws-staging

#### DynamoDB Tables
- businesses-staging
- products-staging
- orders-staging
- websocket-connections-staging
- notifications-staging

#### S3 Buckets
- whizz-merchants-assets-staging
- whizz-business-uploads-staging

### Environment Variables

Frontend (`lib/config/environment.dart`):
```dart
static const String environment = 'staging';
static const String apiUrl = 'https://api-staging.whizz.com/merchants';
static const String wsUrl = 'wss://ws-staging.whizz.com';
static const String cognitoPoolId = 'us-east-1_MERCHANTS_STG';
```

Backend (`template.yaml`):
```yaml
Globals:
  Function:
    Environment:
      Variables:
        ENVIRONMENT: staging
        BUSINESSES_TABLE: businesses-staging
        PRODUCTS_TABLE: products-staging
        ORDERS_TABLE: orders-staging
```

## 📦 ما تم استبعاده

### ✅ Excluded (لن يؤثر على النشر)
- `build/` (530MB) - Flutter build artifacts
- `.dart_tool/` (236MB) - Flutter cache
- `.aws-sam/` (249MB) - SAM build cache
- `node_modules/` - يُعاد تثبيته عبر npm install
- `*.md` files (84 ملف) - Documentation
- `*.backup`, `*.bak` - Backup files
- Test scripts

### ✅ Included (ضروري للنشر)
- Source code (`lib/`, `functions/`)
- Configuration files (`pubspec.yaml`, `template.yaml`)
- Assets (`android/`, `ios/`, `assets/`)
- SAM config (`samconfig.toml`)

## 🔄 سير العمل

### Development → Staging
1. اختبار التغييرات في dev
2. نسخ التحديثات إلى whizzMerchants-stg
3. Push إلى Git branch: `staging`
4. `sam deploy --config-env staging`
5. اختبار شامل في staging

### Staging → Production
1. التحقق من جميع الميزات في staging
2. مراجعة الأكواد
3. Merge من `staging` إلى `main`
4. `sam deploy --config-env production`

## 📝 ملاحظات مهمة

### Backend Architecture
- تطبيق Merchants يستخدم **بنية SAM مختلفة** عن User app
- لا يوجد `package.json` في الجذر
- كل Lambda function قد يكون له `package.json` خاص
- `template.yaml` يحدد جميع الـ functions والموارد

### Lambda Functions Organization
```
functions/
├── auth/              # Authentication functions
├── orders/            # Order management
├── products/          # Product management
├── websocket/         # Real-time connections
└── notifications/     # Push notifications
```

## 🎯 الخطوات التالية

1. ✅ إنشاء Cognito User Pool للـ staging
2. ✅ إنشاء DynamoDB tables مع environment='stg'
3. ✅ تحديث `template.yaml` للـ staging
4. ✅ تحديث frontend config للـ staging
5. ✅ نشر Backend: `sam deploy --config-env staging`
6. ✅ اختبار التطبيق بالكامل

## 📞 الدعم

- الحجم الأصلي: 1.1 GB
- الحجم النظيف: 43 MB
- نسبة التقليل: 96%
- ملفات Dart: 187
- Lambda Functions: 38
- Template.yaml: 112 KB

---

**ملاحظة:** هذا مجلد staging نظيف - الملفات الأصلية في `whizzMerchants/` لم تُمَس!
