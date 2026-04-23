-- =============================================================================
-- NL-Query: PostgreSQL Retail Database Seed Data
-- =============================================================================
-- This script initializes the retail database with departments, products,
-- customers, and a user-department mapping table for RBAC reference.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 1. Departments
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS departments (
    department_id   SERIAL PRIMARY KEY,
    name            VARCHAR(100) NOT NULL UNIQUE,
    slug            VARCHAR(50)  NOT NULL UNIQUE,
    description     TEXT,
    created_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO departments (name, slug, description) VALUES
('Accessories',   'accessories',   'Bags, watches, jewelry, sunglasses, belts, and other fashion accessories'),
('Electronics',   'electronics',   'Consumer electronics including phones, laptops, tablets, and peripherals'),
('Apparel',       'apparel',       'Clothing, footwear, and fashion items for men, women, and children'),
('Home & Garden', 'home_garden',   'Furniture, kitchenware, home décor, garden tools, and outdoor living');

-- ---------------------------------------------------------------------------
-- 2. Products
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS products (
    product_id      SERIAL PRIMARY KEY,
    sku             VARCHAR(20)    NOT NULL UNIQUE,
    name            VARCHAR(200)   NOT NULL,
    department      VARCHAR(50)    NOT NULL,   -- matches departments.slug
    category        VARCHAR(100),
    brand           VARCHAR(100),
    price           DECIMAL(10,2)  NOT NULL,
    cost            DECIMAL(10,2),
    launched_at     DATE,
    is_active       BOOLEAN DEFAULT TRUE,
    created_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Accessories (10 products)
INSERT INTO products (sku, name, department, category, brand, price, cost, launched_at) VALUES
('ACC-001', 'Classic Leather Belt',           'accessories', 'Belts',       'Heritage Co.',    45.99,  18.00, '2024-01-15'),
('ACC-002', 'Aviator Sunglasses',             'accessories', 'Eyewear',    'ShadeCraft',      129.99, 42.00, '2024-03-01'),
('ACC-003', 'Canvas Weekender Bag',           'accessories', 'Bags',       'TravelLux',       89.99,  35.00, '2024-02-20'),
('ACC-004', 'Silver Chain Necklace',          'accessories', 'Jewelry',    'Gleam Studio',    65.00,  22.00, '2024-04-10'),
('ACC-005', 'Digital Sports Watch',           'accessories', 'Watches',    'TimeZone',        199.99, 75.00, '2023-11-05'),
('ACC-006', 'Silk Pocket Square Set',         'accessories', 'Scarves',    'Heritage Co.',    34.99,  12.00, '2024-05-01'),
('ACC-007', 'Leather Cardholder Wallet',      'accessories', 'Wallets',    'Heritage Co.',    55.00,  20.00, '2024-01-20'),
('ACC-008', 'Beaded Bracelet Pack',           'accessories', 'Jewelry',    'Gleam Studio',    28.99,  9.00,  '2024-06-15'),
('ACC-009', 'Wool Fedora Hat',                'accessories', 'Hats',       'TopShelf',        75.00,  30.00, '2024-02-01'),
('ACC-010', 'Crossbody Phone Bag',            'accessories', 'Bags',       'TravelLux',       42.99,  16.00, '2024-07-10');

-- Electronics (10 products)
INSERT INTO products (sku, name, department, category, brand, price, cost, launched_at) VALUES
('ELC-001', 'UltraSlim Laptop 15"',           'electronics', 'Laptops',    'TechNova',       1299.99, 850.00, '2024-01-10'),
('ELC-002', 'Wireless Noise-Cancel Headphones','electronics','Audio',      'SoundWave',       249.99, 95.00,  '2024-02-15'),
('ELC-003', 'Smart Home Hub',                 'electronics', 'Smart Home', 'ConnectIQ',       149.99, 55.00,  '2024-03-20'),
('ELC-004', '4K Action Camera',               'electronics', 'Cameras',    'FramePro',        399.99, 160.00, '2024-04-01'),
('ELC-005', 'Portable Bluetooth Speaker',     'electronics', 'Audio',      'SoundWave',       79.99,  28.00,  '2024-05-15'),
('ELC-006', 'Tablet Pro 11"',                 'electronics', 'Tablets',    'TechNova',        699.99, 420.00, '2024-06-01'),
('ELC-007', 'Mechanical Gaming Keyboard',     'electronics', 'Peripherals','KeyForge',        159.99, 60.00,  '2024-01-25'),
('ELC-008', 'USB-C Docking Station',          'electronics', 'Peripherals','TechNova',        129.99, 48.00,  '2024-03-10'),
('ELC-009', 'Wireless Charging Pad',          'electronics', 'Chargers',   'ConnectIQ',       39.99,  14.00,  '2024-07-01'),
('ELC-010', 'Smart Fitness Tracker',          'electronics', 'Wearables',  'FitPulse',        179.99, 65.00,  '2024-02-28');

-- Apparel (10 products)
INSERT INTO products (sku, name, department, category, brand, price, cost, launched_at) VALUES
('APR-001', 'Slim Fit Oxford Shirt',          'apparel', 'Shirts',      'UrbanThread',    59.99,  22.00, '2024-01-05'),
('APR-002', 'High-Rise Skinny Jeans',         'apparel', 'Denim',       'DenimCraft',     89.99,  32.00, '2024-02-10'),
('APR-003', 'Merino Wool Sweater',            'apparel', 'Knitwear',    'WoolMark',       120.00, 48.00, '2024-03-15'),
('APR-004', 'Lightweight Running Sneakers',   'apparel', 'Footwear',    'StridePro',      139.99, 52.00, '2024-04-20'),
('APR-005', 'Waterproof Parka',               'apparel', 'Outerwear',   'StormShield',    249.99, 95.00, '2024-05-01'),
('APR-006', 'Linen Summer Dress',             'apparel', 'Dresses',     'UrbanThread',    79.99,  28.00, '2024-06-10'),
('APR-007', 'Tailored Chino Pants',           'apparel', 'Trousers',    'UrbanThread',    69.99,  25.00, '2024-01-30'),
('APR-008', 'Performance Polo Shirt',         'apparel', 'Activewear',  'StridePro',      49.99,  18.00, '2024-07-15'),
('APR-009', 'Leather Chelsea Boots',          'apparel', 'Footwear',    'CobbleCraft',    189.99, 72.00, '2024-02-25'),
('APR-010', 'Zip-Up Fleece Jacket',           'apparel', 'Outerwear',   'StormShield',    95.00,  38.00, '2024-08-01');

-- Home & Garden (10 products)
INSERT INTO products (sku, name, department, category, brand, price, cost, launched_at) VALUES
('HMG-001', 'Ceramic Dinner Set (16pc)',      'home_garden', 'Kitchenware',  'TableCraft',    89.99,  35.00, '2024-01-12'),
('HMG-002', 'Ergonomic Office Chair',         'home_garden', 'Furniture',    'ComfortZone',   349.99, 140.00,'2024-02-18'),
('HMG-003', 'Stainless Steel Cookware Set',   'home_garden', 'Kitchenware',  'ChefLine',      199.99, 80.00, '2024-03-22'),
('HMG-004', 'Indoor Herb Garden Kit',         'home_garden', 'Garden',       'GreenThumb',    45.99,  18.00, '2024-04-05'),
('HMG-005', 'Memory Foam Mattress Topper',    'home_garden', 'Bedding',      'DreamRest',     129.99, 50.00, '2024-05-10'),
('HMG-006', 'Solar Garden Light Set',         'home_garden', 'Garden',       'GreenThumb',    59.99,  22.00, '2024-06-20'),
('HMG-007', 'Velvet Throw Pillow Set (4pc)',  'home_garden', 'Home Décor',   'CozyNest',      64.99,  24.00, '2024-01-28'),
('HMG-008', 'Cordless Stick Vacuum',          'home_garden', 'Appliances',   'CleanSweep',    279.99, 110.00,'2024-07-05'),
('HMG-009', 'Wooden Bookshelf 5-Tier',        'home_garden', 'Furniture',    'WoodWorks',     159.99, 62.00, '2024-03-01'),
('HMG-010', 'Automatic Drip Irrigation Kit',  'home_garden', 'Garden',       'GreenThumb',    74.99,  28.00, '2024-08-10');

-- ---------------------------------------------------------------------------
-- 3. Customers (with PII fields for column masking demo)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS customers (
    customer_id     SERIAL PRIMARY KEY,
    first_name      VARCHAR(100) NOT NULL,
    last_name       VARCHAR(100) NOT NULL,
    email           VARCHAR(200) NOT NULL UNIQUE,
    phone           VARCHAR(20),
    address         TEXT,
    city            VARCHAR(100),
    state           VARCHAR(50),
    zip_code        VARCHAR(10),
    loyalty_tier    VARCHAR(20) DEFAULT 'bronze',
    registered_at   DATE,
    created_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO customers (first_name, last_name, email, phone, address, city, state, zip_code, loyalty_tier, registered_at) VALUES
('Alice',    'Johnson',    'alice.johnson@email.com',    '555-0101', '123 Maple Street',      'New York',      'NY', '10001', 'gold',     '2023-01-15'),
('Bob',      'Smith',      'bob.smith@email.com',        '555-0102', '456 Oak Avenue',        'Los Angeles',   'CA', '90001', 'silver',   '2023-02-20'),
('Carol',    'Williams',   'carol.williams@email.com',   '555-0103', '789 Pine Road',         'Chicago',       'IL', '60601', 'platinum', '2023-03-10'),
('David',    'Brown',      'david.brown@email.com',      '555-0104', '321 Elm Boulevard',     'Houston',       'TX', '77001', 'bronze',   '2023-04-05'),
('Eve',      'Davis',      'eve.davis@email.com',        '555-0105', '654 Cedar Lane',        'Phoenix',       'AZ', '85001', 'gold',     '2023-05-18'),
('Frank',    'Martinez',   'frank.martinez@email.com',   '555-0106', '987 Birch Drive',       'Philadelphia',  'PA', '19101', 'silver',   '2023-06-22'),
('Grace',    'Garcia',     'grace.garcia@email.com',     '555-0107', '147 Walnut Court',      'San Antonio',   'TX', '78201', 'bronze',   '2023-07-30'),
('Henry',    'Rodriguez',  'henry.rodriguez@email.com',  '555-0108', '258 Spruce Way',        'San Diego',     'CA', '92101', 'gold',     '2023-08-14'),
('Iris',     'Wilson',     'iris.wilson@email.com',      '555-0109', '369 Cherry Place',      'Dallas',        'TX', '75201', 'platinum', '2023-09-25'),
('Jack',     'Anderson',   'jack.anderson@email.com',    '555-0110', '741 Ash Terrace',       'San Jose',      'CA', '95101', 'silver',   '2023-10-08'),
('Karen',    'Thomas',     'karen.thomas@email.com',     '555-0111', '852 Poplar Circle',     'Austin',        'TX', '73301', 'bronze',   '2023-11-12'),
('Leo',      'Taylor',     'leo.taylor@email.com',       '555-0112', '963 Hickory Loop',      'Jacksonville',  'FL', '32099', 'gold',     '2023-12-01'),
('Maria',    'Moore',      'maria.moore@email.com',      '555-0113', '159 Sycamore Trail',    'Fort Worth',    'TX', '76101', 'silver',   '2024-01-17'),
('Nathan',   'Jackson',    'nathan.jackson@email.com',   '555-0114', '267 Magnolia Path',     'Columbus',      'OH', '43085', 'bronze',   '2024-02-23'),
('Olivia',   'White',      'olivia.white@email.com',     '555-0115', '378 Cypress Gate',      'Charlotte',     'NC', '28201', 'platinum', '2024-03-09'),
('Paul',     'Harris',     'paul.harris@email.com',      '555-0116', '489 Redwood Square',    'Indianapolis',  'IN', '46201', 'gold',     '2024-04-14'),
('Quinn',    'Clark',      'quinn.clark@email.com',      '555-0117', '591 Sequoia Ridge',     'San Francisco', 'CA', '94101', 'silver',   '2024-05-28'),
('Rachel',   'Lewis',      'rachel.lewis@email.com',     '555-0118', '603 Juniper Hollow',    'Seattle',       'WA', '98101', 'bronze',   '2024-06-06'),
('Sam',      'Robinson',   'sam.robinson@email.com',     '555-0119', '714 Fir Crossing',      'Denver',        'CO', '80201', 'gold',     '2024-07-19'),
('Tina',     'Walker',     'tina.walker@email.com',      '555-0120', '825 Beech Summit',      'Nashville',     'TN', '37201', 'silver',   '2024-08-25');

-- ---------------------------------------------------------------------------
-- 4. User-Department Mapping (for reference / alternate RBAC lookup)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS user_department_map (
    id              SERIAL PRIMARY KEY,
    username        VARCHAR(100) NOT NULL,
    department      VARCHAR(50)  NOT NULL,
    role            VARCHAR(50)  NOT NULL,
    created_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(username, department)
);

INSERT INTO user_department_map (username, department, role) VALUES
('accessories_mgr',  'accessories',  'catalog_manager'),
('electronics_mgr',  'electronics',  'catalog_manager'),
('apparel_mgr',      'apparel',      'catalog_manager'),
('home_garden_mgr',  'home_garden',  'catalog_manager'),
('merch_analyst',    'accessories',  'analyst'),
('merch_analyst',    'electronics',  'analyst'),
('merch_analyst',    'apparel',      'analyst'),
('merch_analyst',    'home_garden',  'analyst'),
('data_admin',       'accessories',  'admin'),
('data_admin',       'electronics',  'admin'),
('data_admin',       'apparel',      'admin'),
('data_admin',       'home_garden',  'admin');

-- ---------------------------------------------------------------------------
-- 5. Indexes for query performance
-- ---------------------------------------------------------------------------
CREATE INDEX idx_products_department ON products(department);
CREATE INDEX idx_products_sku ON products(sku);
CREATE INDEX idx_customers_loyalty ON customers(loyalty_tier);
CREATE INDEX idx_user_dept_map_username ON user_department_map(username);
