# Merchant platform transition

The complete onboarding API is not enabled. Personal registration, a post-OTP profile and private drafts are implemented in `../functions/auth/person_onboarding.js`. `npm test` validates domain rules. `template.yaml` defines an isolated Staging data table only; it does not migrate or publish a new registration workflow.

- PERSON#sub / PROFILE: live verified identity, lifecycle and schema version.
- ORGANIZATION#uuid / PROFILE: ownership and organization state.
- ORGANIZATION#uuid / BRAND#uuid: commercial brand.
- BRANCH#existing-businessId / PROFILE: references the current operational branch ID. No wallet re-keying.
- MEMBER#uuid / PROFILE: subject, organization, branch scopes, permissions and version.
- DEVICE#uuid / PROFILE and SESSION#uuid / PROFILE: versioned branch/device/person scopes; device reception and employee sessions remain separate.
- Audit and idempotency records use separate keys. No OTP or PIN plaintext.

SubjectIndex and OrganizationIndex return keys only. Authorization uses a consistent base-table read and a transactional condition on current membership/device/lifecycle versions. A stale GSI is never proof of permission.

Personal records use PERSON#sub / PROFILE and PERSON#sub / DRAFT#uuid. Writes fence the account deletion marker; the personal deletion worker queries this partition and removes owned records under its lease. Drafts stay OFFLINE/DRAFT and never write operational businesses or wallets. Account acknowledgment is stored verbatim after authentication; it does not replace the pending partnership agreement.

Before operational branch activation: complete organization/brand links, geography, file handling, submission and central review, verify migration inventory, complete retention/restore contracts for every new record type, and pass integration tests. This table is not the missing legacy WhizzMerchants_Users table; do not silently change old registrations to it.

Run `python3 backend/merchant-platform/deploy-staging.py` from the merchant repository root with renewed AWS SSO. It verifies the Staging account and deploys cleanup before enabling personal writes. No data migration or SMS test is performed by this script.
