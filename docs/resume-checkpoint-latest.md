# Resume checkpoint — 2026-10-22

User requested saving progress and stopping until later. Read the shared checkpoint in ../whizzCentralPlatform-stg/docs/resume-checkpoint-2026-10-22-292.md before continuing.

Customer build222 and merchant build231 installed on simulators; driver profile221 on real phone. Human order ORD1792697497756 delivered and settled8500; platform goods discount500 consumed once, fixed delivery1500, driver2750, merchant payable5950 locked (not paid), platform contribution−200. Commission remains15%;27% was a hypothetical calculation only. No automatic new order or financial actions on resume. Session source changes saved in local commits; no GitHub push requested during save.

293: resumed human test. Before creating the merchant-funded500 offer, user requested Arabic-only offer creation and overflow repair. Offers workspace/dialogs scoped to ar/RTL, missing translations completed, full-width type/value fields replace cramped row, keyboard inset handling, nine widget/model tests passed. Build232 for merchant simulator; no campaign/order creation or financial changes by agent. See merchant-offer-arabic-form-293.md. Next: user creates fixed500/allItems/minimum7000 from restaurant app and sends saved card; then verify source funding before placing order.


## 319 — GitHub handoff requested
User authorized publishing all session updates for colleague pull. Scope: four staging repositories on feature/malwersh/bootstrap; legacy non-staging worktrees excluded. Repository-specific Arabic handoff record: docs/github-handoff-2026-10-23.json. Current batch passed: Drivers54Node+7Python+65Flutter, Merchants6Flutter, Customers2Flutter; Central docs whitespace checked. Driver native258 installed, final demand colors secondary navy and12h ص/م. No financial operation or new AWS deployment performed for GitHub upload. Detailed commit messages and GitHub commit comments describe scope and pending work.


## GitHub handoff and product/import delegation — 2026-10-24

User requested all four staging repos on feature/malwersh/bootstrap ready for colleague pull, with detailed commit messages and GitHub commit comments. docs/github-handoff-2026-10-24.json records repository changes, validation, pull instructions and scope. Full manual products/CSV/Excel/menu/options/images/catalog/stock/branch/versioned publish work delegated to colleague; canonical handoff docs/merchant-products-import-colleague-handoff-2026-10-24.txt in Central and Merchants. Main plan and transition/product plans mark DELEGATED_TO_COLLEAGUE, not complete. Agent must not implement a parallel importer; coordinate order/pricing/stock/COD contracts. No new AWS deployment/business action as part of upload. Next ongoing COD work remains pickup issue resolution, respecting delegated menu/item-change ownership.


### تصحيح254 — وضوح مصير الطلب بعد فك إسناد السائق
أضيف عرض البحث عن سائق بديل اعتمادًا على financialRelease وحالة الطلب وعدم وجود سائق، مع إعطاء أولوية لحالة تعذر العثور على سائق. تحفظ الإشارة في الذاكرة وتزال عند إسناد بديل. أصل الخادم أُصلح في Central عبر المضيف والمنسق الموحدين؛ الطلب ORD1792870714924 وصل تلقائيًا إلى مراجعة تعذر العثور بعد انتهاء مهلة البحث دون إلغاء. التغيير ليس إكمالًا لفحوص جاهزية الإطلاق على النظامين المؤجلة؛ إعادة الإسناد البشرية لطلب جديد بعد الإصلاح ما زالت تحتاج تجربة.


## تصحيح مرجع الأولويات — الخطة كاملة، 2026-10-24
طلب المستخدم مراجعة جميع بنود الخطة الأساسية عبر التطبيقات الأربعة، وليس استثناءاتCODأوتطبيقًامنفردًا. المرجع الموحد ../whizzCentralPlatform-stg/docs/main-plan-all-apps-priority-review-2026-10-24.json وCSVالمرافق، معالقسمالشاملبختامfinance-pricing-settlements-returns-unified-plan.md. يشمل61بندًاو127قسممواصفةوالحزم14معحالةودليلومتبقٍوأولوية؛ الموجودلايعادبناؤهوغيرالمثبتلايسمىمكتملًا. المنتجاتوالقوائموكلنطاقالاستيرادوالمخزونالمحالللزميلمستثنىمنتنفيذنا،وليسباقيتطبيقالمطعم. يبدأالعملمنسدالضرورياتالتشغيليةحسبالتبعياتعبرالجميع،ثمفحوصالإطلاقAndroid+iPhoneبعدإكمالالتشغيلواختباره.


## شحن محفظة السائق وزين كاش — 260

مرجع الدليل الكامل في Central-stg: `docs/zaincash-readiness-260.json`. جُهّز الوصل والدفع المباشر وإعدادات الأسرار والتجربة المحددة والتفعيل العام والمطابقة والاستعادة. LIVE وUAT الجديدان معطلان؛ بيانات UAT مهيأة ومصادقة OAuth ناجحة دون دفع. القبول البشري وبيانات الشركة والإشعار الفعلي باقية، فلا إعلان اكتمال F02 أو خطة التطبيقات كلها. الطلبات للزبون نقدية، وصرف المطعم الحالي و6000 المعلق لا يتغيران. المنتجات/import للزميل، وبقية أولويات الدفعة محفوظة.

Transfer visibility batch270: Release243 installed on real iMohammed. Existing CONFIG#TRANSFERS.enabled gates transfer entry/actions with fail-closed refresh on resume and30s polling. Balance/history and uncertain-attempt recovery remain available; no commission and no actual transfer created. DRIVER additionally reads posted cancellation entitlement+matching case operation from Holds; ORD1792849495126 has500IQD already credited, now shown as compensation, not unknown delivery earnings. Missing proof differs from known pending review. Central evidence docs/trip-transfer-controls-270.json. User confirms no payment license or partner transfer contract: public money-transfer classification and commission need Iraqi legal/provider review before launch.


## 313 — توحيد مناطق الزبون والمطعم وخيارات العنوان
نُشرت سبع خدمات على staging وتطابقت بصماتها: قارئ إحداثيات الزبون، إنشاء وتعديل العناوين، قوائم المنطقة والقريب، وتسجيل المطعم وإعدادات موقعه. تُقرأ الحدود والفهرس المركب وحالة المصدر والمشتق والآباء الحالية؛ لا يُكتفى بمعرّف منطقة محفوظ. حفظ عنوان الزبون يشتق المنطقة من GPS على الخادم ويضم تحقق إصدارات مراجعها مع حارس الحساب في معاملة الكتابة. تحقق موقع المطعم يستعمل قارئ H3/Polygon نفسه ويطابق المسار المختار كاملاً. غياب الحالة المشتقة يمنع القبول. منح IAM الجديدة قراءة/تحقق فقط لمراجع المناطق، مع حفظ بقية الصلاحيات والبيئات والحزم.
اختيار العنوان الأول وشريط العنوان في الرئيسية يعرض بحث Google القائم، الموقع الحالي، وشجرة العراق ← المحافظة ← القضاء ← مركز القضاء/الناحية. تُعرض فروع التوصيل المفتوحة فقط من مرجع منشور، مع تحميل وإعادة محاولة دون مناطق اختبارية ثابتة. اختيار الناحية يفتح الخريطة لتأكيد نقطة فعلية داخلها؛ مركز الخريطة للعرض فقط ولا يُحفظ كعنوان تلقائي. توجد رسالة توضيح، ويُمنع اعتماد نتيجة تحقق قديمة بعد تحريك النقطة. العناوين المحفوظة تعاد مراجعتها عند الاستخدام؛ أوقفت ذاكرة البحث القديمة ذات الساعة وسماح المتابعة عند تعذر التحقق.
قوائم المطاعم والخريطة تستخدم الإحداثيات والحدود الحالية؛ لا يعتمد إدراج المطعم على regionId المخزن وحده. حُفظت حقول التقييم الحالية. أُصلح تحميل المزيد والمسار الاحتياطي في الرئيسية كي لا يتحولا إلى GPS بدلاً من العنوان المختار، مع إسقاط رد العنوان السابق عند التبديل. عند غياب عنوان صالح يُعاد الاختيار. فهرس جغرافي مخصص للمطاعم غير موجود حالياً: بقي Scan القائم مع ترقيم جميع الصفحات وتقليل المرشحين بصندوق المنطقة ثم اختبار المضلع؛ إضافة فهرس مكاني للمطاعم قبل التوسع الكبير بند أداء لاحق، لا ادعاء بأنه أُنجز.
في المطعم: رُبط قارئ المناطق المهيأ عند التشغيل بـauth/onboarding-regions بدلاً من localhost/regions/active؛ مدة ذاكرة العرض30 ثانية، والتحقق الفعلي من الخادم. نُقل مدخل التسجيل القديم إلى PersonRegistrationScreen الحديث. التسجيل الحالي وتعديل الموقع يستعملان المسار الإداري والمعرّفات الحقيقية؛ نقل مطعم فعلي يبقى خاضعاً لمسار مراجعته القائم.
التحقق:11 اختبار Node للزبون،16 للمطعم،6 Flutter للزبون و4 للمطعم؛ المجموع37. فحوص HTTP فعلية: شجرة الزبون12عنصراً مع آبائها، شجرة تسجيل المطعم15، منطقة الاختبارRmhvcpnn3iy5f1، القائمتان أعادتا4مطاعم، وموقع خارج التغطية404. فُحصت قوالب YAML، ونجح بناء النسختين313 وتثبيتهما وتشغيلهما على iPhone16Pro للزبون وiPhone16 للمطعم، مع حفظ بيانات التطبيق. لا أخطاء أو تحذيرات محلل في الملفات المفحوصة؛ بقيت ملاحظات تنسيق/طباعة معلوماتية قائمة.
لم يُنشئ الوكيل عنواناً أو مطعماً فعلياً أو طلباً ولم يغيّر حدود المناطق أو حساباً مالياً. الحدود السبع التي تحتاج مراجعة من312 ما زالت بحاجة لقرار بشري؛ لم تُخمن إحداثياتها. لا رفع GitHub في هذه الجولة. المرجع:region-consumers-publication-313.json، والتنفيذ التفصيلي:customer-merchant-regions-313.md.
الاختبارات البشرية المطلوبة بالترتيب: البحث بعنوان Google والتحقق من المنطقة؛ GPS داخل وخارج التغطية ومع رفض الإذن؛ توسيع الشجرة واختيار ناحية وتثبيت نقطة داخلها وتجربة خارجها؛ تغيير عنوان محفوظ بعد تحديث حدود المنطقة؛ مطابقة مطاعم الرئيسية والخريطة وتحميل المزيد بعد تبديل العنوان؛ إنشاء/تصحيح موقع مطعم في مسار التسجيل الحديث مع منع موقع خارج الناحية؛ إغلاق منطقة من الإدارة والتحقق من منع العمليات الجديدة مع بقاء الطلب الجاري. لم تُعتبر هذه الاختبارات ناجحة نيابة عن المستخدم.
التالي بعد هذا الاختبار: استئناف بقيةD01 لتوافق فئة الطلب مع المركبة؛ لا إغلاق كاملD01. المنتجات والاستيراد المفوضان للزميل خارج النطاق، ومستحق المطعم6000 المتروك بطلب المستخدم لم يُمس.

## 2026-10-29 — M05 branch device audit resumed
- Reviewed branch-device reception, PIN/session lifecycle, scoped operations and local regression coverage.
- Fixed stale profile response crossing from an old staff session into a newly unlocked session in BranchDeviceHomeScreen. Kept reception-only order projection intentional; employee dashboard independently supplies scoped credentials.
- Regression: 89 backend tests pass (NODE_PATH=backend/functions/auth/node_modules); 11 Flutter tests pass, including delayed profile + lock + second unlock.
- Local frontend change only, not built/installed/deployed. Next: deployed route/package parity, install fix and preserve human pairing/revocation/background reception acceptance in M05.
- Driver exclusive-device work session remains explicitly deferred by user.

### M05 follow-up — build 351 installed
- Merchant simulator build 351 installed and launched successfully (PID 27847), data retained.
- Read-only AWS audit via CLI: unified auth branch-device modules match; device authorizer TTL zero; 15 method definitions protected. Runtime POST /branch-device targets unified auth. Orders drift only unused settlements action; hours copies include older unrelated runtime actions. Products bundle contains scope/session/device/membership rejection markers; exact bundle parity remains open.
- No AWS writes. Detailed sanitized evidence: central docs/branch-device-audit-351.json. Deployed-stage export and exact bundled product parity remain next, alongside queued human device acceptance.

### 2026-10-29 — M05 deployed parity closed; M06 audited
- Rebuilt products with original runtime336 esbuild options; deployed bundle equals rebuild after syntax/whitespace normalization (SHA 0bbca9ecf3e3336c31ca0015c68ce2acbe9df820e10a901721ac01e08e84d2ca). Stage `staging` export confirms all 15 branch-device methods protected and routed correctly. 31 product scope/menu/lifecycle tests passed. Human device acceptance remains open.
- M06: deployed auth/status order-reception.js exact matches local. Worker staging-merchant-response-99 Active/REQUIRED, schedule enabled rate(1 minute), correct target. Followed index wrapper to actual _discount_review/merchant-response-worker/index.js; 11 downloaded-function-body scenarios pass with local tested helpers/in-memory fixtures. Also 17 response/pause +17 hours/status tests passed. No AWS writes or test branch pause performed.
- Central evidence: docs/merchant-hours-pause-audit-351.json, main M06 updated. Human timed pause/resume/manual override/admin suspension/seven-day acceptance queued. Business profile data edits remain separate from this timing audit.

### 2026-10-29 — M06 business profile audit complete (human acceptance open)
- Read-only Lambda parity: live business_changes.js + domain, business_profile_handler.js, location_settings_handler.js and staff merchant-changes.js + domain match local transformed sources exactly.
- Existing behavior verified: owner-only proposals, no approved name/location overwrite while pending, direct profile allowlist, employee capability restrictions, admin origin+destination scope, geometry revalidation and atomic business/request/queue/audit with lifecycle/version guards.
- 29 merchant tests +5 admin tests passed; two new admin regressions cover origin/destination-only access rejection and failed approval geometry causing zero writes.
- No runtime changes needed or deployed. Central evidence docs/merchant-business-profile-audit-351.json and main M06 updated to RUNTIME_AUDITED_HUMAN_ACCEPTANCE_OPEN.
- Next scope-check priority: A10 financial correction after prior payout / negative settlement balance; human tests remain ordered in main plan.

### 2026-10-29 — A10 post-payout audit: real gap confirmed
- 67 source tests pass: merchant payout, frozen batches, preview, return continuation. Payout requires positive amount and claim/proof; no second original payout. Appeal resolution cannot impersonate unchanged financial rights when findings change.
- Live staff merchant-payouts.js exact matches. Full settlement-runtime.js differs due later live overlays (delivery284, cancellation compensation and admin-retry298). DO NOT overwrite with local bundle. createMerchantPayoutService, verifyMerchantPayoutJournal and readMerchantStatementPayment bodies match after normalization.
- Missing actual post-payout linked correction, branch receivable/carry-forward/recovery and positive adjustment payable integration. General company documents do not implement this. No funds/records/services changed.
- Central docs/post-payout-correction-audit-351.json + A10 updated with five implementation stages and human acceptance; status remains gap/not implemented. Next is implementation of the linked correction path, not claiming A10 complete.

### 2026-10-29 — A10 local correction ledger/review UI implemented, NOT deployed
- Central merchant-corrections.js: staff propose/approve/reject tied to verified paid payable/journal, branch/owner lifecycle + authority fences, approval caps, separate balanced journal/branch position/order cumulative totals/audit/retry event. Read-only owner API; no original/wallet mutations.
- Wired through existing merchant-payouts router; Arabic admin frontend/merchant-corrections.js mounted in payouts; read-only Flutter MerchantSettlementCorrections widget in owner account section. Company chart/extractor/projection recognize verified correction journal.
- Tests: 44 backend correction+company, 10 existing merchant payout/account,3 widget branch/error/owner display, browser synthetic retry/review scenario passes; Flutter analyzer clean. Existing 67 financial regression tests rerun.
- User question pending: future settlement offset vs manual debt collection. Do not infer answer. No automatic offset activated.
- Still REQUIRED: real credit disbursement integration, chosen debt recovery/collection, case completion link, exact live-package overlays + scoped permission proof, staging publish and app install/human acceptance. Do not call A10 complete or newly posted position paid/recovered. All new changes local only; no money changed.
- Evidence central docs/post-payout-correction-implementation-351.json. Main A10 status LOCAL_CORRECTION_LEDGER_REVIEW_UI_IMPLEMENTED_RECOVERY_PENDING.

### 2026-10-29 — A10 correction offsets/carry-forward published to staging (352)
- Supersedes earlier local-only checkpoint: user approved OFFSET_NEXT_SETTLEMENT with carried remainder; policy initialized and editable centrally.
- Three backend packages published with original unrelated entries/config preserved; hosting job 223 six-file delta byte verified. Merchant simulator build 352 installed/launched. Central publication receipt and implementation evidence are docs/post-payout-correction-{publication,implementation}-352.json.
- Separate immutable correction journals; reserve source-linked credits/debt with ordinary payout; finalize exactly once, cancel releases; net-zero settles by offset without cash. Original paid statements and balances were not edited during deployment.
- 147 backend regression tests, 21 retention tests, 13 Flutter tests; synthetic browser and deployed-bundle wiring passed. No real financial correction/payout created for testing.
- Human acceptance remains queued in main A10. Do not call full A10 complete: standalone credit payout without future sales and case/appeal closure after changed findings still need implementation. Limits: max 16 correction sources per atomic payout, explicit guard rather than silent omission; one active correction-bearing payout per branch.

### 2026-10-29 — A10 standalone correction payout and linked case review (353)
- Supersedes 352 remaining implementation gaps: owner can request correction credit without future sales, using same registered cashbox/owner receipt/admin reconciliation, or zero-cash offset. Distinct CORRECTIONS_ONLY source/MCP record, not a fictitious sales batch; no original payable or operating merchant wallet debit.
- Admin case page chooses corrections from this order only; link atomically opens correction review. Completion requires full sealed paid allocation proofs, preserves original closure and unrelated reviews; only linked merchant-owner financial appeal can resolve. Original unfinished financial closure still needs existing normal close action.
- Closure guards published in actual staging-driver-financial-accept and staff cancellation runtimes; original effective closure bodies preserved except guard. Retention updated first, then guards, then staff. Hosting 224 byte verified; merchant simulator 353 installed/launched.
- Narrow case metadata managed policy (inline role budget exhausted; inline attempt applied no change). No permission to update financial amount attributes. No real correction/payout/case action performed during publication.
- 98 backend regression tests, 11 Flutter tests, analyzer no issues, browser case/approval/offset tests and actual host SDK route bridge passed. Human acceptance is queued in main A10. No GitHub push in this turn.
- Evidence central docs/post-payout-correction-{implementation,publication}-353.json.
