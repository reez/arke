# Documentation Inventory & Modernization Plan

**Last Updated:** April 30, 2026  
**Total Documentation Files:** 156  
**Purpose:** Comprehensive inventory of all documentation to guide modernization efforts

---

## Executive Summary

### Overview Statistics

| Category | Count | % of Total |
|----------|-------|------------|
| Root-level files | 36 | 23% |
| Send feature | 23 | 15% |
| Initialization docs | 15 | 10% |
| Archive (historical) | 21 | 14% |
| Address history | 10 | 6% |
| Other subdirectories | 49 | 32% |
| **TOTAL** | **154** | **100%** |

### Document Types

| Type | Count | Status |
|------|-------|--------|
| Summary/Complete docs | 34 | Often redundant |
| Implementation guides | 23 | Mix of current/outdated |
| Fix/Bug documentation | 11 | Historical value only |
| Migration documents | 10 | Should be in Archive |
| Quick references | 6 | Valuable, keep |
| Refactoring docs | 3 | Historical |
| Planning docs | 1 | Current |
| Uncategorized | 76 | Needs review |

### Documentation Health

- **Total Lines:** ~31,296 lines across all files
- **Average File Size:** 191 lines
- **Largest File:** INITIALIZATION_FLOWS.md (1,442 lines)
- **Last Major Update:** April 15, 2026 (theme-system-implementation.md)
- **Oldest Active Reference:** October 24, 2025

---

## Critical Issues Identified

### 1. Duplicate Documentation (HIGH PRIORITY)

#### Exact Duplicate File Names
- **PHASE_3_COMPLETE.md** exists in both:
  - `Address history/PHASE_3_COMPLETE.md`
  - `Movements/PHASE_3_COMPLETE.md`
  
- **IMPLEMENTATION_SUMMARY.md** exists in both:
  - `Payment destination selection/IMPLEMENTATION_SUMMARY.md`
  - `Security device separation/IMPLEMENTATION_SUMMARY.md`

- **QUICK_REFERENCE.md** exists in both:
  - `Payment destination selection/QUICK_REFERENCE.md`
  - `Security device separation/QUICK_REFERENCE.md`

- **intro.md** exists in 4 directories (appropriate for section intros):
  - `API/intro.md`
  - `Architecture/intro.md`
  - `Development/intro.md`
  - `Features/intro.md`

#### Content Duplicates (Near-Identical)

1. **Address History Phase 3 Duplicates:**
   - `Address history/PHASE_3_COMPLETE_SUMMARY.md` (120 lines)
   - `Address history/PHASE_3_COMPLETE_SUMMARY 2.md` (425 lines) ← **DUPLICATE FILE**
   - **Recommendation:** Delete "PHASE_3_COMPLETE_SUMMARY 2.md", keep the comprehensive version

2. **README vs Intro Duplicates:**
   - `README.md` (46 lines, updated Oct 30, 2025)
   - `Intro.md` (50 lines, updated Oct 24, 2025)
   - **Overlap:** 95% identical content with different link paths
   - **Recommendation:** Merge into single README.md, delete Intro.md

3. **Device Registry Phase Documentation:**
   - `DEVICE_REGISTRY_PHASE1_SUMMARY.md`
   - `DEVICE_REGISTRY_PHASE2_SUMMARY.md`
   - `DEVICE_REGISTRY_PHASE3_SUMMARY.md`
   - `DEVICE_REGISTRY_ALL_PHASES_COMPLETE.md`
   - `DEVICE_REGISTRY_COMPLETE.md` ← **REDUNDANT**
   - **Recommendation:** Archive phase summaries, keep only COMPLETE version

4. **SendView Documentation Redundancy:**
   - `Send/SENDVIEW_INTEGRATION_SUMMARY.md`
   - `Send/SENDVIEW_REFACTORING_SUMMARY.md`
   - `Send/SENDVIEW_OVERVIEW.md`
   - **Overlap:** Similar architectural information repeated
   - **Recommendation:** Consolidate into single SendView architecture doc

### 2. Misplaced Historical Documentation

Files that should be in Archive but aren't:

#### Migration Documents (Root Level → Should be Archived)
- `migration-history.md` ← Summary of archived migrations
- `BitcoinFormatter-Migration.md`
- `BitcoinFormatter-Refactoring-Summary.md`
- `CONTACT_DETAIL_IOS_MIGRATION.md`
- `TRANSACTION_DETAIL_IOS_MIGRATION.md`
- `WALLET_DELETION_REFACTOR_SUMMARY.md`
- `ADDRESS_PARSING_REFACTOR_SUMMARY.md`

#### FFI Integration (Directory → Should be Archived)
- Entire `FFI initial integration/` directory (6 files)
- All PHASE*_COMPLETE.md files (historical implementation)

#### Initialization Fixes (Should be Archived)
- `Initialization/DOUBLE_WALLET_INITIALIZATION_FIX.md`
- `Initialization/DOUBLE_INITIALIZATION_FIX_CORRECTED.md`
- `Initialization/FIX_DUPLICATE_MNEMONIC_SAVES.md`
- `Initialization/CLOUDKIT_NOTIFICATION_STORM_FIX.md`
- `Initialization/BATCH_TAG_CREATION_FIX.md`
- All tracing/logging enhancement docs (completed work)

### 3. Orphaned or Unclear Purpose

Files requiring review for current relevance:

- `BEFORE_AFTER_COMPARISON.md` (no context, what comparison?)
- `DataVersionObservation.md` (no recent references)
- `tags-view-architecture.md` (superseded by Features/tag-system.md?)
- `movements.md` (vs. Movements/ directory - which is current?)
- `BarkTypes.md` (API reference or historical?)
- `process-state-service-implementation.md` (completed? current?)

### 4. Incomplete Documentation Chains

#### CPFP Implementation
- `cpfp_package_relay_solution.md`
- `bark_issue_cpfp_package_relay.md`
- `BDK/CPFP-Implementation-Plan.md`
- **Issue:** Three related docs, unclear which is current plan

#### Passkey Integration
- `PASSKEY_INTEGRATION_PLAN.md` (1,300 lines)
- `PASSKEY_INTEGRATION_PLAN_REVIEW.md`
- **Status:** Planning phase, not implemented yet

---

## Directory-by-Directory Inventory

### Root Level (36 files) ⚠️ HIGH PRIORITY FOR CLEANUP

**Status: BLOATED** - Too many root-level files, needs categorization

#### Should Keep (Core Documentation)
- ✅ `README.md` - Main documentation index (merged with Intro.md on 2026-04-24)

#### Archived (Historical) - Completed 2026-04-24
Migration/Refactoring docs moved to Archive/:
- ✅ `migration-history.md` → Archive/
- ✅ `BitcoinFormatter-Migration.md` → Archive/
- ✅ `BitcoinFormatter-Refactoring-Summary.md` → Archive/
- ✅ `CONTACT_DETAIL_IOS_MIGRATION.md` → Archive/
- ✅ `TRANSACTION_DETAIL_IOS_MIGRATION.md` → Archive/
- ✅ `WALLET_DELETION_REFACTOR_SUMMARY.md` → Archive/
- ✅ `WALLET_DELETION_IMPLEMENTATION.md` → Archive/
- ✅ `ADDRESS_PARSING_REFACTOR_SUMMARY.md` → Archive/
- ✅ `DELETION_UX_REFACTOR.md` → Archive/
- ✅ `REFACTORING_SUMMARY.md` → Archive/

#### Should Archive (Historical)
Migration/Refactoring docs:
- `BitcoinFormatter-Locale-Guide.md`

Device Registry (move to Archive):
- `DEVICE_REGISTRY_ALL_PHASES_COMPLETE.md`
- `DEVICE_REGISTRY_COMPLETE.md`
- `DEVICE_REGISTRY_PHASE1_SUMMARY.md`
- `DEVICE_REGISTRY_PHASE2_SUMMARY.md`
- `DEVICE_REGISTRY_PHASE3_SUMMARY.md`

#### Should Move to Feature Directories
- `ACCESSIBILITY.md` → `Features/accessibility.md`
- `DEFAULT_CONTACT_IMPLEMENTATION.md` → `Contacts/`
- `WALLET_FIRST_INITIALIZATION.md` → `Initialization/`
- `SIGNET_FAUCET_IMPLEMENTATION.md` → `Features/` or `Development/`
- `INTRO_VIDEO_PLAYER_GUIDE.md` → `Features/`
- `SCRATCH_CARD_IMPLEMENTATION.md` → `Features/`
- `CONTACT_ADDRESS_DELETION_LOGIC.md` → `Contacts/`

#### Needs Review (Current Status Unclear)
- `APNS_MAILBOX_SPEC.md` - Specification doc, current?
- `PASSKEY_INTEGRATION_PLAN.md` - Planning, not implemented
- `PASSKEY_INTEGRATION_PLAN_REVIEW.md` - Related to above
- `Fee-Calculation-Analysis.md` - Analysis doc, current?
- `bark_issue_cpfp_package_relay.md` - Issue tracking?
- `cpfp_package_relay_solution.md` - Solution to above?
- `BarkTypes.md` - API reference, move to API/?
- `CloudKitSyncImplementation.md` - Move to CloudKit/?
- `DataVersionObservation.md` - Implementation detail?
- `movements.md` - Duplicate of Movements/ directory?
- `process-state-service-implementation.md` - Implementation guide?
- `tags-view-architecture.md` - Superseded by Features/tag-system.md?

#### BIP39 Documentation (Move to Features/)
- `BIP39_INTEGRATION_GUIDE.md`
- `BIP39_QUICK_REFERENCE.md`
- `BIP39_TROUBLESHOOTING.md`

#### Payment Flow (Keep, but organize)
- `PAYMENT_DESTINATION_SELECTOR_README.md`
- `QUICK_PAYMENT_SOURCE_GUIDE.md`
- `NETWORK_MISMATCH_UX_CHANGES.md`
- `FIX_DATABASE_ERROR_AFTER_DELETION.md`

---

### Architecture/ (6 files) ✅ GOOD STRUCTURE

**Status: CURRENT** - Well-organized, keep as-is

- ✅ `intro.md` - Section introduction
- ✅ `system-overview.md` - High-level architecture
- ✅ `data-flow.md` - Data flow documentation
- ✅ `service-layer.md` - Service documentation
- ✅ `network-configuration-guide.md` - Network setup
- ✅ `network-configuration-persistence.md` - Network configuration persistence

**Assessment:** This directory is well-maintained and follows good documentation structure.

---

### API/ (3 files) ✅ GOOD STRUCTURE

**Status: CURRENT** - Well-organized

- ✅ `intro.md` - Section introduction
- ✅ `model-definitions.md` - Data models (495 lines)
- ✅ `service-interfaces.md` - Service interfaces

**Recommendation:** Consider moving `BarkTypes.md` from root here.

---

### Features/ (4 files) ✅ GOOD STRUCTURE

**Status: CURRENT** - Could be expanded

- ✅ `intro.md` - Section introduction
- ✅ `balance-persistence.md` - Balance caching implementation
- ✅ `tag-system.md` - Tag system implementation
- ✅ `theme-system-implementation.md` - Theme system (most recent: Apr 15, 2026)

**Recommendations:**
- Move BIP39 docs here
- Move accessibility.md here
- Move feature implementation docs from root here
- Consider: `scratch-card.md`, `signet-faucet.md`, `intro-video-player.md`

---

### Development/ (4 files) ✅ GOOD STRUCTURE

**Status: CURRENT** - Essential developer docs

- ✅ `intro.md` - Section introduction
- ✅ `setup.md` - Development setup
- ✅ `testing-patterns.md` - Testing guide (470 lines)
- ✅ `common-tasks.md` - Common workflows (591 lines)

**Assessment:** These are valuable, current documentation. Keep as-is.

---

### Send/ (23 files) ⚠️ NEEDS CONSOLIDATION

**Status: REDUNDANT** - Too much documentation for one feature

#### Implementation Summaries (Overlapping Content)
- `SENDVIEW_INTEGRATION_SUMMARY.md` (206 lines)
- `SENDVIEW_REFACTORING_SUMMARY.md` (156 lines)
- `SENDVIEW_OVERVIEW.md`
- `SENDVIEW_ARCHITECTURE.md`
- **Recommendation:** Consolidate into single "Send Architecture" doc

#### Reference Documentation (Keep)
- ✅ `SENDVIEW_QUICK_REFERENCE.md` (462 lines) - Excellent reference
- ✅ `SENDVIEW_USAGE_GUIDE.md` - User guide
- ✅ `SENDVIEW_USAGE_EXAMPLES.md` (603 lines) - Code examples
- ✅ `PAYMENT_SOURCE_FLOW_REFERENCE.md` - Flow reference

#### Testing & Development (Keep)
- ✅ `SENDVIEW_TEST_SCENARIOS.md` (514 lines) - Test cases
- ✅ `SENDVIEW_PREVIEW_STATES.md` (478 lines) - Preview documentation
- ✅ `SENDVIEW_FLOW_DIAGRAMS.md` - Visual diagrams
- ✅ `SENDVIEW_MIGRATION_CHECKLIST.md` - Migration guide
- ✅ `SENDVIEW_BANNER_COMPARISON.md` - UI comparison

#### Feature-Specific (Keep)
- ✅ `QR_CODE_SOURCE_IMPLEMENTATION.md` - QR implementation
- ✅ `PAYMENT_REQUEST_INFO_BANNER_GUIDE.md` (386 lines)
- ✅ `PAYMENT_REQUEST_INFO_BANNER_IMPLEMENTATION.md`
- ✅ `PAYMENT_REQUEST_INFO_BANNER_VISUAL_REFERENCE.md`
- ✅ `CLIPBOARD_BANNER_ENHANCEMENT.md`
- ✅ `CLIPBOARD_BANNER_BUG_FIX.md`

#### Bug Fixes (Archive)
- `ARK_ADDRESS_FIX_CORRECTED.md`
- `ARK_ADDRESS_VALIDATION_FIX.md`
- `SCENARIO_9_FIX_SUMMARY.md`

**Recommendation:** 
- Merge 4 architecture/summary docs into 1
- Archive bug fix docs
- Keep reference, testing, and feature docs
- Result: ~15 files (from 23)

---

### Address history/ (10 files) ⚠️ NEEDS CLEANUP

**Status: COMPLETED IMPLEMENTATION** - Should archive phase docs

#### Planning (Keep as reference)
- ✅ `ADDRESS_HISTORY_PLAN.md` (557 lines) - Original plan
- ✅ `ADDRESS_IMPLEMENTATION_GUIDE.md` - Implementation guide

#### Current Reference (Keep)
- ✅ `ADDRESS_QUICK_REFERENCE.md` (195 lines) - Developer reference
- ✅ `ADDRESS_IMPLEMENTATION_STATUS.md` - Current status

#### Phase Documentation (Archive)
- `PHASE_3_IMPLEMENTATION.md`
- `PHASE_3_TRANSACTION_INTEGRATION.md` (431 lines)
- `PHASE_3_COMPLETE.md`
- `PHASE_3_COMPLETE_SUMMARY.md`
- `PHASE_3_COMPLETE_SUMMARY 2.md` ← **DUPLICATE, DELETE**

#### Bug Fixes (Archive)
- `FIX_REDECLARATION_ERRORS.md`

**Recommendation:** Keep 4 reference docs, archive 6 phase/fix docs

---

### Movements/ (8 files) ⚠️ ARCHIVE PHASES

**Status: ACTIVE** - Implementation complete, new onchain linking feature added

#### Current (Keep)
- ✅ `MOVEMENT_SYSTEM_COMPLETE.md` - Final summary
- ✅ `TRANSFER_TYPE_IMPLEMENTATION.md` - Implementation details
- ✅ `FEE_DISPLAY_FIX.md` - Fee display fix (current)
- ✅ `Movement_Onchain_Linking.md` - Onchain transaction linking implementation (added 2026-04-28)

#### Archive (Phases)
- `PHASE_1_COMPLETE.md`
- `PHASE_2_COMPLETE.md`
- `PHASE_3_COMPLETE.md`
- `PHASE_4_COMPLETE.md` (385 lines)

**Recommendation:** Keep 4 current docs, archive 4 phase docs

---

### BDK/ (6 files) ✅ MOSTLY CURRENT

**Status: ACTIVE DEVELOPMENT** - Recent updates

#### Current Documentation
- ✅ `BDK-Implementation-Complete.md` - Completion summary
- ✅ `BDK-Integration-Status.md` - Integration status
- ✅ `BDK-Next-Steps.md` - Future work
- ✅ `BDK-Improvements-2026-02-26.md` (436 lines) - Recent improvements
- ✅ `CPFP-Implementation-Plan.md` (1,008 lines) - Current plan
- ✅ `OnchainTransactionService-Implementation.md` - Implementation guide

**Assessment:** All files are current and relevant. Keep all.

**Note:** Coordinate with root-level CPFP docs:
- `cpfp_package_relay_solution.md`
- `bark_issue_cpfp_package_relay.md`

---

### Initialization/ (15 files) ⚠️ MOSTLY HISTORICAL

**Status: COMPLETED FIXES** - Most should be archived

#### Current Reference (Keep)
- ✅ `INITIALIZATION_FLOWS.md` (1,442 lines) - Comprehensive flow doc
- ✅ `REVIEW.md` - System review
- ⚠️ `WALLET_CREATION_ISSUES.md` - If still current
- ⚠️ `WALLET_CREATION_ISSUES_OVERVIEW.md` - If still current

#### Archive (Completed Fixes)
- `DOUBLE_WALLET_INITIALIZATION_FIX.md` (426 lines)
- `DOUBLE_INITIALIZATION_FIX_CORRECTED.md`
- `FIX_DUPLICATE_MNEMONIC_SAVES.md`
- `CLOUDKIT_NOTIFICATION_STORM_FIX.md`
- `BATCH_TAG_CREATION_FIX.md`
- `ENHANCED_CALL_TRACING.md`
- `ENHANCED_INITIALIZATION_LOGGING.md`
- `ADDRESS_GENERATION_TRACING.md`
- `SERVER_CONNECTION_DIAGNOSTICS.md` (495 lines)

#### Issue Tracking (Evaluate)
- `ISSUE_1_DEVICE_REGISTRATION.md`
- `ISSUE_2_ADDRESS_GENERATION.md` (454 lines, updated Feb 26, 2026)

**Recommendation:** Keep 2-4 reference docs, archive 11+ fix docs

---

### Contacts/ (5 files) ⚠️ ARCHIVE MIGRATIONS

**Status: COMPLETED MIGRATIONS** - Archive old, keep reference

#### Archive (Completed Migrations)
- `CONTACTS_VIEW_REFACTOR_COMPLETE.md`
- `CONTACT_DETAIL_IOS_MERGE_SUMMARY.md`
- `FORM_MIGRATION_SUMMARY.md`
- `FORM_MIGRATION_TECHNICAL_DETAILS.md` (576 lines)
- `FORM_MIGRATION_VISUAL_GUIDE.md`

**Recommendation:** All 5 files should move to Archive. Add current Contacts reference to Features/ if needed.

---

### CloudKit/ (3 files) ✅ KEEP

**Status: REFERENCE DOCUMENTATION**

- ✅ `CloudKitQuickStart.md` - Quick start guide
- ✅ `CloudKitSetupChecklist.md` - Setup checklist
- ✅ `CloudKitSyncGuidelines.md` - Sync guidelines

**Recommendation:** Keep all. Consider moving `CloudKitSyncImplementation.md` from root here.

---

### Console/ (3 files) ✅ KEEP

**Status: CURRENT DOCUMENTATION**

- ✅ `CONSOLE_COMMANDS.md` - Command reference
- ✅ `CONSOLE_OPTIMIZATION.md` - Optimization guide
- ✅ `CONSOLE_REFACTOR.md` - Refactoring notes

**Assessment:** Useful development tools documentation. Keep all.

---

### Security device separation/ (6 files) ✅ CURRENT

**Status: COMPLETED IMPLEMENTATION** - Good documentation

- ✅ `IMPLEMENTATION_SUMMARY.md` - Implementation overview
- ✅ `SEPARATION_OF_CONCERNS_IMPLEMENTATION.md` - Architecture
- ✅ `ARCHITECTURE_DIAGRAMS.md` - Visual documentation
- ✅ `QUICK_REFERENCE.md` - Developer reference
- ✅ `TESTING_CHECKLIST_SEPARATION.md` - Testing guide
- ✅ `COMMIT_MESSAGE.md` - Historical record

**Recommendation:** Keep all, perhaps archive COMMIT_MESSAGE.md

---

### Payment destination selection/ (4 files) ✅ KEEP

**Status: CURRENT**

- ✅ `IMPLEMENTATION_SUMMARY.md` - Implementation overview
- ✅ `PAYMENT_SELECTION_FLOW_DIAGRAM.md` - Flow diagrams
- ✅ `QUICK_REFERENCE.md` - Developer reference
- ✅ `BUG_FIXES_SUMMARY.md` - Bug fixes

**Recommendation:** Keep all, consider archiving BUG_FIXES_SUMMARY.md

---

### Localization/ (2 files) ✅ KEEP

**Status: RECENT** - Updated March 11, 2026

- ✅ `LOCALIZATION_MIGRATION_SUMMARY.md` - Migration summary
- ✅ `LOCALIZATION_UPDATE_SUMMARY.md` - Update summary

**Assessment:** Recent work, keep both.

---

### FFI initial integration/ (6 files) ⚠️ ARCHIVE ALL

**Status: HISTORICAL** - Initial integration complete

- `PHASE1_COMPLETE.md`
- `PHASE2_COMPLETE.md`
- `PHASE3_COMPLETE.md`
- `PHASE4_COMPLETE.md`
- `PHASES567_COMPLETE.md` (385 lines)
- `FINAL_COMPLETE.md`

**Recommendation:** Move entire directory to Archive/ - this is historical implementation documentation.

---

### Archive/ (21 files) ✅ PROPER USE

**Status: APPROPRIATELY ARCHIVED**

- ✅ `readme.md` - Archive index
- ✅ `architecture-migration.md`
- ✅ `ark-balance-migration.md`
- ✅ `onchain-balance-migration.md`
- ✅ `phase-1-cleanup-summary.md`
- ✅ `phase-2-content-updates.md`
- ✅ `phase-3-completion-summary.md`
- ✅ `tag-models-step-1-implementation.md`
- ✅ `tag-models-step-2-implementation.md`
- ✅ `tag-models-step-3-implementation.md`
- ✅ `tag-models-step-4-implementation.md`
- ✅ `migration-history.md` - Migration summary (archived 2026-04-24)
- ✅ `BitcoinFormatter-Migration.md` - Completed migration (archived 2026-04-24)
- ✅ `BitcoinFormatter-Refactoring-Summary.md` - Completed refactoring (archived 2026-04-24)
- ✅ `CONTACT_DETAIL_IOS_MIGRATION.md` - Completed migration (archived 2026-04-24)
- ✅ `TRANSACTION_DETAIL_IOS_MIGRATION.md` - Completed migration (archived 2026-04-24)
- ✅ `WALLET_DELETION_REFACTOR_SUMMARY.md` - Completed refactoring (archived 2026-04-24)
- ✅ `ADDRESS_PARSING_REFACTOR_SUMMARY.md` - Completed refactoring (archived 2026-04-24)
- ✅ `DELETION_UX_REFACTOR.md` - Completed refactoring (archived 2026-04-24)
- ✅ `REFACTORING_SUMMARY.md` - Generic refactoring summary (archived 2026-04-24)
- ✅ `WALLET_DELETION_IMPLEMENTATION.md` - Completed implementation (archived 2026-04-24)

---

### Data samples/ (1 file + JSON files)

**Status: REFERENCE DATA**

- ✅ `Movements.md` - Movement data documentation
- Multiple JSON sample files in CLI/ subdirectory

**Assessment:** Useful reference data. Keep.

---

## Identified Duplicates & Overlaps

### Exact Duplicates (Delete Immediately)

1. **Address History:**
   - ✅ COMPLETED (2026-04-24): Deleted `Address history/PHASE_3_COMPLETE_SUMMARY 2.md` duplicate

2. **Root README:**
   - ✅ COMPLETED (2026-04-24): Merged `Intro.md` into `README.md` and deleted duplicate

### Near Duplicates (Consolidate)

1. **Device Registry:**
   - Consolidate 5 files into 1 comprehensive doc
   - `DEVICE_REGISTRY_COMPLETE.md` + phase summaries → single doc

2. **SendView Architecture:**
   - Merge into single architecture document:
     - `SENDVIEW_INTEGRATION_SUMMARY.md`
     - `SENDVIEW_REFACTORING_SUMMARY.md`
     - `SENDVIEW_OVERVIEW.md`
     - `SENDVIEW_ARCHITECTURE.md`

3. **Movements/Address History Phases:**
   - Both have PHASE_3_COMPLETE.md (different content)
   - Keep both but clarify in file names: `PHASE_3_MOVEMENTS_COMPLETE.md`

### Content Overlap

1. **CPFP Documentation:**
   - `cpfp_package_relay_solution.md` (root)
   - `bark_issue_cpfp_package_relay.md` (root)
   - `BDK/CPFP-Implementation-Plan.md`
   - **Action:** Review and consolidate, keep plan in BDK/

2. **BitcoinFormatter:**
   - `BitcoinFormatter-Migration.md`
   - `BitcoinFormatter-Refactoring-Summary.md`
   - `BitcoinFormatter-Locale-Guide.md`
   - **Action:** Consolidate into one reference doc, archive migrations

3. **Wallet Deletion:**
   - `WALLET_DELETION_IMPLEMENTATION.md`
   - `WALLET_DELETION_REFACTOR_SUMMARY.md`
   - **Action:** Consolidate into one doc

---

## Recommendations for Consolidation

### Phase 1: Immediate Actions (Quick Wins)

#### Delete Duplicates
1. Delete `Intro.md` (after merging with README.md)
2. Delete `Address history/PHASE_3_COMPLETE_SUMMARY 2.md`
3. Fix double extensions in Archive:
   - Rename `tag-models-step-2-implementation.md.md` → `.md`
   - Rename `tag-models-step-3-implementation.md.md` → `.md`
   - Rename `tag-models-step-4-implementation.md.md` → `.md`

#### Move to Archive (Historical Docs)
**From Root:**
- All Device Registry phase docs (5 files)
- All migration/refactoring docs (12 files)
- Wallet deletion docs (2 files)
- BitcoinFormatter docs (3 files)

**From Subdirectories:**
- `FFI initial integration/` entire directory (6 files)
- `Contacts/` all migration docs (5 files)
- `Initialization/` all fix docs (9 files)
- `Movements/` all phase docs (4 files)
- `Address history/` all phase docs (5 files)
- `Send/` bug fix docs (3 files)

**Total to Archive:** ~54 files

### Phase 2: Reorganization

#### Create New Feature Directories
1. **Features/bip39/**
   - Move BIP39_INTEGRATION_GUIDE.md
   - Move BIP39_QUICK_REFERENCE.md
   - Move BIP39_TROUBLESHOOTING.md

2. **Features/payments/**
   - Move PAYMENT_DESTINATION_SELECTOR_README.md
   - Move QUICK_PAYMENT_SOURCE_GUIDE.md
   - Consolidate with Payment destination selection/ directory

3. **Features/ui-components/**
   - Move ACCESSIBILITY.md
   - Move INTRO_VIDEO_PLAYER_GUIDE.md
   - Move SCRATCH_CARD_IMPLEMENTATION.md

#### Consolidate Directories
1. **Merge "Payment destination selection/" into Send/**
   - They're closely related
   - Reduces top-level directory count

2. **Move security docs to appropriate homes:**
   - Security device separation → Architecture/ or Features/

### Phase 3: Content Consolidation

#### High-Priority Consolidations

1. **SendView Documentation** (23 → ~15 files)
   - Create `Send/ARCHITECTURE.md` (merge 4 architecture docs)
   - Keep all reference, testing, and feature docs
   - Archive bug fixes

2. **Device Registry** (5 → 1 file)
   - Create `Archive/device-registry-implementation.md`
   - Consolidate all phase summaries

3. **CPFP Implementation** (3 → 1 file)
   - Create `BDK/cpfp-implementation.md`
   - Consolidate root-level CPFP docs into BDK directory

4. **BitcoinFormatter** (3 → 1 file)
   - Create `Archive/bitcoin-formatter-migration.md`
   - Consolidate all three docs

5. **Initialization** (15 → 3-4 files)
   - Keep INITIALIZATION_FLOWS.md
   - Keep REVIEW.md
   - Create TROUBLESHOOTING.md (if issues still current)
   - Archive all fix docs

### Phase 4: New Structure Creation

#### Create Master Index Documents

1. **FEATURES_INDEX.md**
   - Comprehensive list of all implemented features
   - Links to relevant documentation
   - Status of each feature (stable, experimental, deprecated)

2. **ARCHITECTURE_INDEX.md**
   - System architecture overview
   - Links to detailed component docs
   - Decision records (ADRs)

3. **DEVELOPMENT_INDEX.md**
   - Development workflow
   - Common tasks
   - Troubleshooting guides

#### Create Quick Start Guides

1. **QUICK_START.md**
   - New developer onboarding
   - Essential reading (top 5 docs)
   - Setup checklist

2. **CONTRIBUTING.md**
   - How to contribute
   - Documentation standards
   - PR process

---

## Priority Actions

### Immediate (This Week)

1. ✅ Create this inventory document
2. ✅ Delete exact duplicates (2 files completed: Intro.md merged and deleted 2026-04-24, PHASE_3_COMPLETE_SUMMARY 2.md deleted 2026-04-24)
3. ✅ Fix Archive file extensions (3 files)
4. ✅ Merge README.md and Intro.md (completed 2026-04-24)
5. ✅ Archive 10 most obvious historical docs (completed 2026-04-24)

**Impact:** Reduce from 164 → 151 files (-13)

### Short Term (This Month)

1. Archive all phase completion docs (~30 files)
2. Archive all fix/bug docs (~15 files)
3. Consolidate Device Registry docs (5 → 1)
4. Consolidate BitcoinFormatter docs (3 → 1)
5. Reorganize root-level files into subdirectories

**Impact:** Reduce from 149 → ~110 files (-39)

### Medium Term (Next Quarter)

1. Consolidate SendView documentation (23 → 15)
2. Consolidate Initialization docs (15 → 4)
3. Create feature directories for loose root files
4. Create master index documents
5. Create quick start guides

**Impact:** Reduce from 110 → ~80 files (-30)
**Total Reduction:** 164 → 80 files (-51%)

### Long Term (Ongoing)

1. Establish documentation lifecycle policy
2. Regular quarterly reviews
3. Automated documentation health checks
4. Link validation
5. Code reference verification

---

## Documentation Standards (Proposed)

### File Naming Conventions

- **Feature Docs:** `feature-name.md` (lowercase, hyphens)
- **Architecture:** `ARCHITECTURE_topic.md` (uppercase for importance)
- **API:** `api-component.md` (lowercase)
- **Quick Reference:** `topic-reference.md` (not QUICK_REFERENCE)
- **No "SUMMARY" in names** - all docs should be summaries
- **No phase numbers** - use git history for implementation phases

### Directory Structure

```
Docs/
├── README.md                    # Main entry point
├── QUICK_START.md              # New developer guide
├── CONTRIBUTING.md             # How to contribute
│
├── Architecture/               # System architecture
│   ├── index.md
│   ├── system-overview.md
│   └── ...
│
├── API/                        # API reference
│   ├── index.md
│   └── ...
│
├── Features/                   # Feature documentation
│   ├── index.md
│   ├── payments/
│   ├── security/
│   ├── ui-components/
│   └── ...
│
├── Development/                # Developer guides
│   ├── index.md
│   ├── setup.md
│   ├── testing.md
│   └── common-tasks.md
│
└── Archive/                    # Historical docs
    ├── index.md
    ├── migrations/
    ├── completed-implementations/
    └── deprecated/
```

### Documentation Lifecycle

1. **Planning:** High-level plan document
2. **Implementation:** Track in git commits, not docs
3. **Completion:** Create/update feature documentation
4. **Maintenance:** Update feature docs as needed
5. **Deprecation:** Move to Archive with deprecation note

### What NOT to Document

- Individual bug fixes (use git commits)
- Phase-by-phase implementation (use git history)
- Refactoring steps (use git commits)
- Temporary workarounds (use code comments)

### What TO Document

- Feature purpose and architecture
- API interfaces and usage examples
- Development workflows
- Testing patterns
- Configuration guides
- Troubleshooting guides

---

## Code Reference Verification

### Referenced Classes/Files to Verify

Common references found in documentation:

#### Models
- `PersistentAddress` - Address history feature
- `PersistentTransaction` - Transaction model
- `PersistentTag` - Tag system
- `TransactionTagAssignment` - Tag relationships
- `ArkBalance` / `OnchainBalance` - Balance models

#### Services
- `AddressService` - Address management
- `TransactionService` - Transaction handling
- `TagService` - Tag operations
- `WalletManager` - Wallet coordination
- `TaskDeduplicationManager` - Task management

#### Views
- `SendView` / `SendView_iOS` - Send functionality
- `TagsView` / `TagsView_iOS` - Tag management
- `ReceiveView` - Receive functionality
- `TransactionDetailView` - Transaction details

**Verification Status:** PENDING  
**Action Required:** Run automated check against codebase

---

## Metrics & Health Indicators

### Current State (April 22, 2026)

| Metric | Value | Health |
|--------|-------|--------|
| Total Files | 164 | ⚠️ Too many |
| Root Files | 46 | 🔴 Critical |
| Duplicate Files | 5+ | ⚠️ Needs cleanup |
| Archived Files | 11 | 🔴 Too few |
| Phase Docs | 18 | ⚠️ Should archive |
| Fix Docs | 11 | ⚠️ Should archive |
| Avg File Age | Unknown | - |
| Broken Links | Unknown | - |
| Code References | Unverified | - |

### Target State (Q3 2026)

| Metric | Target | Status |
|--------|--------|--------|
| Total Files | ~80 | 🎯 51% reduction |
| Root Files | <10 | 🎯 Clear structure |
| Duplicate Files | 0 | 🎯 Eliminated |
| Archived Files | ~70 | 🎯 Proper history |
| Phase Docs | 0 | 🎯 Git history |
| Fix Docs | 0 | 🎯 Git history |
| Documentation Coverage | 90%+ | 🎯 Comprehensive |
| Broken Links | 0 | 🎯 Validated |
| Code References | 100% valid | 🎯 Verified |

---

## Update History

| Date | Author | Changes |
|------|--------|---------|
| 2026-04-24 | Claude Code | Archived 10 historical migration/refactoring docs to Archive/ directory |
| 2026-04-24 | Claude Code | Deleted duplicate PHASE_3_COMPLETE_SUMMARY 2.md from Address history/ |
| 2026-04-24 | Claude Code | Merged Intro.md into README.md and deleted duplicate |
| 2026-04-24 | Claude Code | Fixed Archive file extensions (3 files) |
| 2026-04-22 | Claude Code | Initial comprehensive inventory created |

---

## Notes for Future Maintainers

### This Inventory is a Living Document

- Update this inventory as you make changes
- Track progress on consolidation efforts
- Add notes about decisions made
- Document any discovered issues

### Automation Opportunities

1. **File counter:** Script to update statistics automatically
2. **Link checker:** Validate all internal links
3. **Code reference checker:** Verify referenced classes exist
4. **Duplicate detector:** Find similar content across files
5. **Age tracker:** Flag docs not updated in 6+ months

### When to Archive

Archive documentation when:
- Implementation is complete and stable
- Document describes a specific bug fix
- Document tracks phase-by-phase implementation
- Document is superseded by newer documentation
- Document is no longer referenced in codebase

### When to Delete

Only delete documentation when:
- It's an exact duplicate
- Content has been merged elsewhere
- Information is completely obsolete and has no historical value
- File was created in error

**Default action: ARCHIVE, not DELETE**

---

**END OF INVENTORY**
