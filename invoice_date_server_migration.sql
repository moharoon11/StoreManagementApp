-- Store Management: selectable invoice date
-- Run once on existing MySQL 8.0.46+ databases before deploying API support
-- for the `invoiceDate` checkout request field.
-- The API should save that YYYY-MM-DD value into Invoices.InvoiceDate and
-- use InvoiceDate (rather than CreatedAt) for calendar-based sale reports.

USE `store_management_db`;

ALTER TABLE `Invoices`
    ADD COLUMN IF NOT EXISTS `InvoiceDate` DATE DEFAULT NULL AFTER `BalanceDue`;

-- Preserve the calendar date of all existing invoices.
UPDATE `Invoices`
SET `InvoiceDate` = DATE(`CreatedAt`)
WHERE `InvoiceDate` IS NULL;

CREATE INDEX `idx_invoices_user_invoice_date`
    ON `Invoices` (`UserId`, `InvoiceDate`);
