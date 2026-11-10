# Enterprise gap matrix and roadmap

Status as of 2026-11-06. This covers the project's priorities, not every Enterprise feature.

"Pinned" means the module exists on its 19.0 branch and is locked in `deps/vendor.lock`. Nothing
here has been install-tested or visually checked yet, and existing on 19.0 doesn't prove a
module works well or matches Enterprise. The first CI run provides the first install test.

## 1. Chile localization: the largest gap

| Capability | Community 19 status | Plan |
|---|---|---|
| Chart of accounts, taxes, document types, RUT, banks | Core `l10n_cl` | Install it, then check its coverage in the demo |
| Electronic invoicing (DTE with the SII) | Not in core. OCA `l10n-chile` has no 19.0 modules | Evaluate porting, see below |
| Chile financial and tax reports (F29, purchase and sales books) | No `l10n_cl_reports` in Community | Build on `mis_builder` and `account_tax_balance` |
| Chile payroll (AFP, health, Previred, tax) | Nothing found for 19 | Custom module on OCA `payroll` |
| UF and UTM rates | Not yet checked | Check core `l10n_cl` currency data, then decide |

**DTE options:**

| Option | Upside | Risk |
|---|---|---|
| Port `TuringForgeSpA/tf_dte_cl` from 18.0 (recommended to evaluate first) | Active project, one version behind | Code quality unreviewed. A similarly named repo shows a different licence, so provenance needs checking |
| Port `l10n_cl_fe` from 16.0 | AGPL-3 with long history | Three versions behind |
| Write a demo-only module | Fastest and fully ours | Must be clearly labelled as non-fiscal, and it never talks to the SII |

Any real SII use needs separate certification and is outside this demo's scope.

## 2. User interface

| Enterprise feature | Candidate | Status |
|---|---|---|
| Full-screen app menu, responsive layout | OCA `web_responsive` (Production/Stable) | Pinned, in `modules.txt` |
| Sidebar, colours, chatter and dialog options | `muk_web_theme` and its parts | Pinned, not installed. May overlap `web_responsive`, so compare them first |
| Enterprise-like colours, spacing and login | Our own `jc_enterprise_look` module | To build |

`muk_web_enterprise_theme` is **not** usable here: it depends on `web_enterprise`. Assets for the
custom look must be original, not copied from Enterprise.

## 3. Finance

| Enterprise feature | Community replacement | Status |
|---|---|---|
| Financial reports | `account_financial_report`, `mis_builder` | Pinned |
| Tax reports | `account_tax_balance` | Pinned |
| Bank reconciliation | `account_reconcile_oca` | Pinned |
| Bank statement import | `account_statement_import_file` | Pinned. Bank formats still to check |
| Assets | `account_asset_management` | Pinned |
| Fiscal years, lock dates | `account_fiscal_year`, `account_lock_date_update` | Pinned |

## 4. Contracts, documents, payroll

| Enterprise feature | Community replacement | Status |
|---|---|---|
| Subscriptions and recurring billing | `contract` | Pinned. Similar, not identical |
| Documents | `dms` | Pinned |
| Payroll | `payroll` | Pinned. `payroll_account` isn't on 19.0 yet, so accounting integration is a gap |

## Licensing

Several finance modules and `contract` are AGPL-3. If a modified AGPL module is offered to users
over a network, they must be able to get its source; a public repo makes that straightforward.
Get legal advice before any commercial use.

## Roadmap

Each step is one or more PRs, and CI must pass before merging.

1. **Foundation:** this repo, CI, and the first full install test.
2. **Server:** the Oracle server, staging, production.
3. **Interface:** compare `web_responsive` and MuK with screenshots, then build `jc_enterprise_look`.
4. **Demo data:** a fictional Chilean company with coherent flows, seeded by script so it can be rebuilt.
5. **Chile DTE:** evaluate the options above, then decide.
6. **Finance:** configure reports and build the Chile tax views.
7. **Contracts, documents, payroll:** configure them, then build the Chile payroll layer.
