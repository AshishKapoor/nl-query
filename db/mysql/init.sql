-- =============================================================================
-- NL-Query: MySQL Inventory Database Seed Data
-- =============================================================================
-- This script initializes the inventory database with sales records,
-- suppliers, and warehouse stock levels. All key tables include a
-- department column for Trino row-filter RBAC enforcement.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 1. Suppliers
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS suppliers (
    supplier_id     INT AUTO_INCREMENT PRIMARY KEY,
    name            VARCHAR(200) NOT NULL,
    department      VARCHAR(50)  NOT NULL,
    contact_email   VARCHAR(200),
    contact_phone   VARCHAR(20),
    country         VARCHAR(100),
    rating          DECIMAL(2,1) DEFAULT 3.0,
    created_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO suppliers (name, department, contact_email, contact_phone, country, rating) VALUES
('Heritage Leather Works',    'accessories',  'orders@heritageleather.com',  '555-1001', 'Italy',         4.5),
('TechNova Components',       'electronics',  'supply@technova.com',         '555-1002', 'South Korea',   4.8),
('UrbanThread Textiles',      'apparel',      'bulk@urbanthread.com',        '555-1003', 'Vietnam',       4.2),
('GreenThumb Garden Supply',  'home_garden',  'wholesale@greenthumb.com',    '555-1004', 'USA',           4.0),
('SoundWave Audio Ltd',       'electronics',  'parts@soundwave.com',         '555-1005', 'Japan',         4.7),
('DenimCraft Mills',          'apparel',      'fabric@denimcraft.com',       '555-1006', 'Turkey',        3.9),
('Gleam Studio Jewelry',      'accessories',  'gems@gleamstudio.com',        '555-1007', 'Thailand',      4.3),
('ComfortZone Furniture',     'home_garden',  'orders@comfortzone.com',      '555-1008', 'China',         3.8),
('StridePro Manufacturing',   'apparel',      'factory@stridepro.com',       '555-1009', 'Indonesia',     4.1),
('ChefLine Kitchenware',      'home_garden',  'supply@chefline.com',         '555-1010', 'Germany',       4.6);

-- ---------------------------------------------------------------------------
-- 2. Warehouse Stock
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS warehouse_stock (
    stock_id        INT AUTO_INCREMENT PRIMARY KEY,
    sku             VARCHAR(20)  NOT NULL,
    department      VARCHAR(50)  NOT NULL,
    warehouse       VARCHAR(50)  NOT NULL,
    quantity        INT          NOT NULL DEFAULT 0,
    reorder_level   INT          NOT NULL DEFAULT 10,
    last_restocked  DATE,
    updated_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- Accessories stock across warehouses
INSERT INTO warehouse_stock (sku, department, warehouse, quantity, reorder_level, last_restocked) VALUES
('ACC-001', 'accessories', 'EAST-01', 150, 30, '2024-08-01'),
('ACC-002', 'accessories', 'EAST-01', 85,  20, '2024-07-15'),
('ACC-003', 'accessories', 'WEST-01', 200, 40, '2024-08-10'),
('ACC-004', 'accessories', 'WEST-01', 120, 25, '2024-07-20'),
('ACC-005', 'accessories', 'EAST-01', 60,  15, '2024-08-05'),
('ACC-006', 'accessories', 'CENTRAL-01', 300, 50, '2024-08-12'),
('ACC-007', 'accessories', 'CENTRAL-01', 175, 35, '2024-07-25'),
('ACC-008', 'accessories', 'WEST-01', 250, 45, '2024-08-08'),
('ACC-009', 'accessories', 'EAST-01', 90,  20, '2024-07-30'),
('ACC-010', 'accessories', 'CENTRAL-01', 110, 25, '2024-08-15');

-- Electronics stock
INSERT INTO warehouse_stock (sku, department, warehouse, quantity, reorder_level, last_restocked) VALUES
('ELC-001', 'electronics', 'EAST-01', 45,  10, '2024-08-01'),
('ELC-002', 'electronics', 'WEST-01', 120, 25, '2024-07-20'),
('ELC-003', 'electronics', 'CENTRAL-01', 200, 40, '2024-08-05'),
('ELC-004', 'electronics', 'EAST-01', 75,  15, '2024-07-15'),
('ELC-005', 'electronics', 'WEST-01', 300, 50, '2024-08-10'),
('ELC-006', 'electronics', 'EAST-01', 55,  12, '2024-08-12'),
('ELC-007', 'electronics', 'CENTRAL-01', 180, 35, '2024-07-25'),
('ELC-008', 'electronics', 'WEST-01', 150, 30, '2024-08-08'),
('ELC-009', 'electronics', 'CENTRAL-01', 400, 60, '2024-07-30'),
('ELC-010', 'electronics', 'EAST-01', 95,  20, '2024-08-15');

-- Apparel stock
INSERT INTO warehouse_stock (sku, department, warehouse, quantity, reorder_level, last_restocked) VALUES
('APR-001', 'apparel', 'EAST-01', 200, 40, '2024-08-01'),
('APR-002', 'apparel', 'WEST-01', 180, 35, '2024-07-18'),
('APR-003', 'apparel', 'CENTRAL-01', 100, 20, '2024-08-06'),
('APR-004', 'apparel', 'EAST-01', 150, 30, '2024-07-22'),
('APR-005', 'apparel', 'WEST-01', 70,  15, '2024-08-11'),
('APR-006', 'apparel', 'CENTRAL-01', 220, 45, '2024-08-03'),
('APR-007', 'apparel', 'EAST-01', 160, 30, '2024-07-28'),
('APR-008', 'apparel', 'WEST-01', 280, 50, '2024-08-09'),
('APR-009', 'apparel', 'CENTRAL-01', 85,  18, '2024-07-14'),
('APR-010', 'apparel', 'EAST-01', 130, 25, '2024-08-14');

-- Home & Garden stock
INSERT INTO warehouse_stock (sku, department, warehouse, quantity, reorder_level, last_restocked) VALUES
('HMG-001', 'home_garden', 'CENTRAL-01', 100, 20, '2024-08-02'),
('HMG-002', 'home_garden', 'EAST-01', 30,  8,  '2024-07-16'),
('HMG-003', 'home_garden', 'WEST-01', 80,  15, '2024-08-07'),
('HMG-004', 'home_garden', 'CENTRAL-01', 250, 40, '2024-07-21'),
('HMG-005', 'home_garden', 'EAST-01', 60,  12, '2024-08-13'),
('HMG-006', 'home_garden', 'WEST-01', 180, 35, '2024-08-04'),
('HMG-007', 'home_garden', 'CENTRAL-01', 200, 40, '2024-07-26'),
('HMG-008', 'home_garden', 'EAST-01', 40,  10, '2024-08-10'),
('HMG-009', 'home_garden', 'WEST-01', 55,  12, '2024-07-29'),
('HMG-010', 'home_garden', 'CENTRAL-01', 140, 28, '2024-08-16');

-- ---------------------------------------------------------------------------
-- 3. Sales
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS sales (
    sale_id         INT AUTO_INCREMENT PRIMARY KEY,
    sku             VARCHAR(20)    NOT NULL,
    department      VARCHAR(50)    NOT NULL,
    customer_id     INT            NOT NULL,
    quantity        INT            NOT NULL,
    unit_price      DECIMAL(10,2)  NOT NULL,
    total_amount    DECIMAL(10,2)  NOT NULL,
    discount_pct    DECIMAL(5,2)   DEFAULT 0.00,
    sold_at         DATETIME       NOT NULL,
    channel         VARCHAR(20)    DEFAULT 'online',
    created_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Accessories sales (25 records)
INSERT INTO sales (sku, department, customer_id, quantity, unit_price, total_amount, discount_pct, sold_at, channel) VALUES
('ACC-001', 'accessories', 1,  2, 45.99,  91.98,  0.00, '2024-07-01 10:30:00', 'online'),
('ACC-002', 'accessories', 3,  1, 129.99, 129.99, 5.00, '2024-07-02 14:15:00', 'store'),
('ACC-003', 'accessories', 5,  1, 89.99,  89.99,  0.00, '2024-07-03 09:45:00', 'online'),
('ACC-005', 'accessories', 2,  1, 199.99, 199.99, 10.00,'2024-07-05 16:00:00', 'store'),
('ACC-004', 'accessories', 8,  3, 65.00,  195.00, 0.00, '2024-07-06 11:20:00', 'online'),
('ACC-007', 'accessories', 12, 2, 55.00,  110.00, 0.00, '2024-07-08 13:40:00', 'online'),
('ACC-001', 'accessories', 15, 1, 45.99,  45.99,  0.00, '2024-07-10 08:55:00', 'store'),
('ACC-006', 'accessories', 7,  4, 34.99,  139.96, 5.00, '2024-07-12 15:30:00', 'online'),
('ACC-010', 'accessories', 19, 1, 42.99,  42.99,  0.00, '2024-07-14 10:10:00', 'store'),
('ACC-008', 'accessories', 4,  2, 28.99,  57.98,  0.00, '2024-07-15 17:25:00', 'online'),
('ACC-002', 'accessories', 11, 1, 129.99, 129.99, 0.00, '2024-07-18 12:00:00', 'online'),
('ACC-009', 'accessories', 6,  1, 75.00,  75.00,  0.00, '2024-07-20 14:45:00', 'store'),
('ACC-003', 'accessories', 14, 2, 89.99,  179.98, 10.00,'2024-07-22 09:30:00', 'online'),
('ACC-005', 'accessories', 17, 1, 199.99, 199.99, 0.00, '2024-07-25 16:15:00', 'online'),
('ACC-001', 'accessories', 9,  3, 45.99,  137.97, 0.00, '2024-07-28 11:50:00', 'store'),
('ACC-004', 'accessories', 20, 1, 65.00,  65.00,  5.00, '2024-08-01 10:00:00', 'online'),
('ACC-007', 'accessories', 1,  1, 55.00,  55.00,  0.00, '2024-08-03 13:20:00', 'online'),
('ACC-002', 'accessories', 10, 1, 129.99, 129.99, 0.00, '2024-08-05 15:40:00', 'store'),
('ACC-006', 'accessories', 13, 2, 34.99,  69.98,  0.00, '2024-08-08 08:30:00', 'online'),
('ACC-010', 'accessories', 16, 1, 42.99,  42.99,  0.00, '2024-08-10 17:00:00', 'online'),
('ACC-008', 'accessories', 3,  3, 28.99,  86.97,  0.00, '2024-08-12 12:15:00', 'store'),
('ACC-009', 'accessories', 18, 1, 75.00,  75.00,  0.00, '2024-08-14 14:30:00', 'online'),
('ACC-001', 'accessories', 5,  1, 45.99,  45.99,  0.00, '2024-08-16 09:00:00', 'store'),
('ACC-003', 'accessories', 8,  1, 89.99,  89.99,  0.00, '2024-08-18 16:45:00', 'online'),
('ACC-005', 'accessories', 12, 1, 199.99, 199.99, 15.00,'2024-08-20 11:10:00', 'online');

-- Electronics sales (25 records)
INSERT INTO sales (sku, department, customer_id, quantity, unit_price, total_amount, discount_pct, sold_at, channel) VALUES
('ELC-001', 'electronics', 2,  1, 1299.99, 1299.99, 0.00,  '2024-07-01 09:00:00', 'online'),
('ELC-002', 'electronics', 4,  2, 249.99,  499.98,  5.00,  '2024-07-02 11:30:00', 'store'),
('ELC-005', 'electronics', 7,  3, 79.99,   239.97,  0.00,  '2024-07-03 14:00:00', 'online'),
('ELC-003', 'electronics', 1,  1, 149.99,  149.99,  0.00,  '2024-07-05 16:30:00', 'online'),
('ELC-006', 'electronics', 10, 1, 699.99,  699.99,  10.00, '2024-07-07 10:15:00', 'store'),
('ELC-004', 'electronics', 15, 1, 399.99,  399.99,  0.00,  '2024-07-09 13:45:00', 'online'),
('ELC-007', 'electronics', 3,  1, 159.99,  159.99,  0.00,  '2024-07-11 08:20:00', 'online'),
('ELC-009', 'electronics', 18, 2, 39.99,   79.98,   0.00,  '2024-07-13 15:55:00', 'store'),
('ELC-010', 'electronics', 6,  1, 179.99,  179.99,  5.00,  '2024-07-15 12:30:00', 'online'),
('ELC-008', 'electronics', 11, 1, 129.99,  129.99,  0.00,  '2024-07-17 17:10:00', 'online'),
('ELC-001', 'electronics', 14, 1, 1299.99, 1299.99, 5.00,  '2024-07-19 09:40:00', 'store'),
('ELC-002', 'electronics', 9,  1, 249.99,  249.99,  0.00,  '2024-07-21 11:00:00', 'online'),
('ELC-005', 'electronics', 20, 2, 79.99,   159.98,  0.00,  '2024-07-23 14:25:00', 'online'),
('ELC-003', 'electronics', 16, 2, 149.99,  299.98,  0.00,  '2024-07-25 16:50:00', 'store'),
('ELC-006', 'electronics', 5,  1, 699.99,  699.99,  0.00,  '2024-07-28 10:05:00', 'online'),
('ELC-007', 'electronics', 13, 2, 159.99,  319.98,  10.00, '2024-08-01 13:15:00', 'online'),
('ELC-009', 'electronics', 8,  3, 39.99,   119.97,  0.00,  '2024-08-03 08:45:00', 'store'),
('ELC-010', 'electronics', 17, 1, 179.99,  179.99,  0.00,  '2024-08-05 15:20:00', 'online'),
('ELC-004', 'electronics', 2,  1, 399.99,  399.99,  5.00,  '2024-08-07 12:00:00', 'online'),
('ELC-008', 'electronics', 19, 2, 129.99,  259.98,  0.00,  '2024-08-09 17:35:00', 'store'),
('ELC-001', 'electronics', 7,  1, 1299.99, 1299.99, 0.00,  '2024-08-11 09:10:00', 'online'),
('ELC-002', 'electronics', 12, 1, 249.99,  249.99,  0.00,  '2024-08-13 14:50:00', 'online'),
('ELC-005', 'electronics', 4,  1, 79.99,   79.99,   0.00,  '2024-08-15 16:00:00', 'store'),
('ELC-003', 'electronics', 1,  1, 149.99,  149.99,  0.00,  '2024-08-18 10:30:00', 'online'),
('ELC-006', 'electronics', 6,  1, 699.99,  699.99,  15.00, '2024-08-20 13:40:00', 'online');

-- Apparel sales (25 records)
INSERT INTO sales (sku, department, customer_id, quantity, unit_price, total_amount, discount_pct, sold_at, channel) VALUES
('APR-001', 'apparel', 3,  2, 59.99,  119.98, 0.00, '2024-07-01 11:00:00', 'online'),
('APR-002', 'apparel', 6,  1, 89.99,  89.99,  0.00, '2024-07-02 13:30:00', 'store'),
('APR-004', 'apparel', 9,  1, 139.99, 139.99, 5.00, '2024-07-04 09:15:00', 'online'),
('APR-003', 'apparel', 12, 1, 120.00, 120.00, 0.00, '2024-07-06 15:45:00', 'store'),
('APR-005', 'apparel', 1,  1, 249.99, 249.99, 0.00, '2024-07-08 12:20:00', 'online'),
('APR-006', 'apparel', 14, 2, 79.99,  159.98, 0.00, '2024-07-10 17:00:00', 'online'),
('APR-007', 'apparel', 7,  3, 69.99,  209.97, 10.00,'2024-07-12 08:40:00', 'store'),
('APR-008', 'apparel', 18, 2, 49.99,  99.98,  0.00, '2024-07-14 14:10:00', 'online'),
('APR-009', 'apparel', 5,  1, 189.99, 189.99, 0.00, '2024-07-16 10:55:00', 'store'),
('APR-010', 'apparel', 11, 1, 95.00,  95.00,  5.00, '2024-07-18 16:30:00', 'online'),
('APR-001', 'apparel', 16, 1, 59.99,  59.99,  0.00, '2024-07-20 09:25:00', 'online'),
('APR-002', 'apparel', 4,  2, 89.99,  179.98, 0.00, '2024-07-22 13:50:00', 'store'),
('APR-004', 'apparel', 20, 1, 139.99, 139.99, 0.00, '2024-07-24 15:15:00', 'online'),
('APR-003', 'apparel', 8,  1, 120.00, 120.00, 0.00, '2024-07-26 11:40:00', 'online'),
('APR-006', 'apparel', 2,  1, 79.99,  79.99,  0.00, '2024-07-28 17:05:00', 'store'),
('APR-007', 'apparel', 15, 2, 69.99,  139.98, 0.00, '2024-08-01 09:30:00', 'online'),
('APR-008', 'apparel', 10, 1, 49.99,  49.99,  0.00, '2024-08-03 14:00:00', 'online'),
('APR-009', 'apparel', 13, 1, 189.99, 189.99, 5.00, '2024-08-05 16:20:00', 'store'),
('APR-010', 'apparel', 19, 2, 95.00,  190.00, 0.00, '2024-08-07 10:45:00', 'online'),
('APR-005', 'apparel', 17, 1, 249.99, 249.99, 0.00, '2024-08-09 12:10:00', 'online'),
('APR-001', 'apparel', 6,  3, 59.99,  179.97, 0.00, '2024-08-11 08:30:00', 'store'),
('APR-002', 'apparel', 1,  1, 89.99,  89.99,  0.00, '2024-08-13 15:50:00', 'online'),
('APR-004', 'apparel', 9,  2, 139.99, 279.98, 10.00,'2024-08-15 17:15:00', 'store'),
('APR-003', 'apparel', 3,  1, 120.00, 120.00, 0.00, '2024-08-17 11:00:00', 'online'),
('APR-006', 'apparel', 14, 1, 79.99,  79.99,  0.00, '2024-08-20 13:30:00', 'online');

-- Home & Garden sales (25 records)
INSERT INTO sales (sku, department, customer_id, quantity, unit_price, total_amount, discount_pct, sold_at, channel) VALUES
('HMG-001', 'home_garden', 4,  1, 89.99,  89.99,  0.00, '2024-07-01 10:00:00', 'online'),
('HMG-002', 'home_garden', 8,  1, 349.99, 349.99, 5.00, '2024-07-03 12:30:00', 'store'),
('HMG-003', 'home_garden', 2,  1, 199.99, 199.99, 0.00, '2024-07-05 14:45:00', 'online'),
('HMG-005', 'home_garden', 11, 2, 129.99, 259.98, 0.00, '2024-07-07 09:20:00', 'online'),
('HMG-004', 'home_garden', 16, 3, 45.99,  137.97, 0.00, '2024-07-09 16:00:00', 'store'),
('HMG-006', 'home_garden', 7,  2, 59.99,  119.98, 0.00, '2024-07-11 11:35:00', 'online'),
('HMG-008', 'home_garden', 1,  1, 279.99, 279.99, 10.00,'2024-07-13 13:50:00', 'store'),
('HMG-007', 'home_garden', 19, 2, 64.99,  129.98, 0.00, '2024-07-15 08:10:00', 'online'),
('HMG-009', 'home_garden', 5,  1, 159.99, 159.99, 0.00, '2024-07-17 15:25:00', 'online'),
('HMG-010', 'home_garden', 13, 1, 74.99,  74.99,  0.00, '2024-07-19 17:40:00', 'store'),
('HMG-001', 'home_garden', 10, 2, 89.99,  179.98, 5.00, '2024-07-21 10:55:00', 'online'),
('HMG-003', 'home_garden', 17, 1, 199.99, 199.99, 0.00, '2024-07-23 12:05:00', 'online'),
('HMG-002', 'home_garden', 3,  1, 349.99, 349.99, 0.00, '2024-07-25 14:30:00', 'store'),
('HMG-005', 'home_garden', 20, 1, 129.99, 129.99, 0.00, '2024-07-27 09:45:00', 'online'),
('HMG-006', 'home_garden', 9,  3, 59.99,  179.97, 0.00, '2024-07-29 16:15:00', 'online'),
('HMG-004', 'home_garden', 14, 2, 45.99,  91.98,  0.00, '2024-08-01 11:30:00', 'store'),
('HMG-007', 'home_garden', 6,  1, 64.99,  64.99,  0.00, '2024-08-03 13:00:00', 'online'),
('HMG-008', 'home_garden', 18, 1, 279.99, 279.99, 5.00, '2024-08-05 08:20:00', 'online'),
('HMG-009', 'home_garden', 12, 1, 159.99, 159.99, 0.00, '2024-08-07 15:40:00', 'store'),
('HMG-010', 'home_garden', 2,  2, 74.99,  149.98, 0.00, '2024-08-09 17:55:00', 'online'),
('HMG-001', 'home_garden', 15, 1, 89.99,  89.99,  0.00, '2024-08-11 10:10:00', 'store'),
('HMG-003', 'home_garden', 7,  1, 199.99, 199.99, 0.00, '2024-08-13 12:45:00', 'online'),
('HMG-002', 'home_garden', 11, 1, 349.99, 349.99, 0.00, '2024-08-15 14:00:00', 'online'),
('HMG-005', 'home_garden', 4,  1, 129.99, 129.99, 0.00, '2024-08-17 09:30:00', 'store'),
('HMG-006', 'home_garden', 1,  1, 59.99,  59.99,  0.00, '2024-08-20 16:20:00', 'online');

-- ---------------------------------------------------------------------------
-- 4. Indexes
-- ---------------------------------------------------------------------------
CREATE INDEX idx_sales_department ON sales(department);
CREATE INDEX idx_sales_sku ON sales(sku);
CREATE INDEX idx_sales_sold_at ON sales(sold_at);
CREATE INDEX idx_sales_customer ON sales(customer_id);
CREATE INDEX idx_warehouse_sku ON warehouse_stock(sku);
CREATE INDEX idx_warehouse_department ON warehouse_stock(department);
CREATE INDEX idx_suppliers_department ON suppliers(department);
