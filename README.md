# Store Management App

## Customer credit invoices setup

1. Run `StoreManagementApi/Scripts/create_customer_credit_invoices.sql` once on the MySQL database configured as `DefaultConnection` for the API.
2. Start the API from `StoreManagementApi` with `dotnet run`.
3. Configure the Flutter API address with `--dart-define=API_BASE_URL=https://your-host/api` when needed, then run the Flutter app.

The **Customer Credit** workspace lists pending balances. A new invoice creates its opening credit transaction; the plus action adds further credit, and **Received** records a settlement and retains the invoice in the database while removing it from the pending list.
