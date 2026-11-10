{
    'name': "Chile Demo Company",
    'version': '19.0.1.0.0',
    'category': 'Accounting/Localizations',
    'summary': "Set the main company to Chile so new databases get the Chilean chart of accounts",
    'description': """
Odoo picks the chart of accounts from the company's country when the localization
installs. A new database has no country yet, so it falls back to the generic chart in
USD. This module depends only on base, so it installs before accounting and sets the
main company's country to Chile. l10n_cl then loads the Chilean chart, taxes and CLP.

It only affects new databases. On a database that already has a chart of accounts,
switch it in Accounting settings instead.
""",
    'author': "Jorge Cubillos",
    'data': [
        'data/res_company_data.xml',
    ],
    'installable': True,
    'license': 'LGPL-3',
}
