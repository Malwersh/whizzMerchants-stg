# Merchant offer form Arabic/layout — 293

User paused the next merchant-funded 500-IQD acceptance test because the creation form mixed English/Arabic and its narrow percentage dropdown overflowed.

The offers workspace and its creation/edit/selection dialogs now use a scoped Arabic locale and RTL direction. Other application sections retain their locale configuration; global language switching remains later work. Missing Arabic translations were added to the ARB and the generated Arabic localization and untranslated report regenerated. Hard-coded quantity/empty-state messages and the card's minimum-order dollar label were corrected for this Arabic workflow.

Extracted MerchantDiscountValueFields renders the type and value as full-width fields, with expanded menus and explicit Arabic percentage/IQD labels. Existing supported types and callback/controller serialization remain in place. Percentage values already stored outside the preset list are preserved when editing. Fixed amount validation rejects non-finite/non-positive values. Keyboard insets lift the form controls, while its content remains scrollable. The server discount contract, funding, commission and delivery agreement are unchanged.

Verification: nine widget/model tests pass, including an Arabic/RTL editor under an English app locale, 320/390/600px widths with 1.3 text scaling, percentage-to-fixed transition, invalid/valid fixed values, and existing non-preset percentage preservation. Static analysis reports existing informational style/deprecation notices and no errors or warnings. Merchant simulator build232 contains the UI fix. No discount or order was created by the agent.

Next human action: open restaurant offers → إنشاء خصم, create merchant-funded fixed500 on all items with minimum7000, send the saved card before placing the next order. The previous platform-funded order ORD1792697497756 remains delivered/settled. Commission remains15%;27% was hypothetical only. Acceptance of merchant-funded/shared/free-delivery paths remains pending.

Build/test artifacts: /private/tmp/merchant-offer-ar-293.
