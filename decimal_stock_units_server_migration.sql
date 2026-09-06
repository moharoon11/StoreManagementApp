-- Store Management: decimal stock quantities and product units
-- Safe to run repeatedly on MySQL 8.0.46+.

USE `store_management_db`;

ALTER TABLE `Products`
    MODIFY COLUMN `StockQuantity` DECIMAL(18,3) NOT NULL DEFAULT 0.000,
    MODIFY COLUMN `SoldsCount` DECIMAL(18,3) NOT NULL DEFAULT 0.000,
    ADD COLUMN IF NOT EXISTS `Unit` VARCHAR(20) NOT NULL DEFAULT 'Piece' AFTER `SoldsCount`;

ALTER TABLE `InvoiceItems`
    MODIFY COLUMN `Quantity` DECIMAL(18,3) NOT NULL,
    ADD COLUMN IF NOT EXISTS `Unit` VARCHAR(20) NOT NULL DEFAULT 'Piece' AFTER `Quantity`;

ALTER TABLE `StockMovements`
    MODIFY COLUMN `PreviousQuantity` DECIMAL(18,3) NOT NULL,
    MODIFY COLUMN `QuantityChanged` DECIMAL(18,3) NOT NULL,
    MODIFY COLUMN `NewQuantity` DECIMAL(18,3) NOT NULL;
