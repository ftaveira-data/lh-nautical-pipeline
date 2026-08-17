-- Gerado automaticamente por src/infer_schema.py.
-- Tipos inferidos a partir de TODAS as linhas de cada arquivo.
-- Arquivos analisados: 24

CREATE SCHEMA IF NOT EXISTS raw;

-- addresses.csv: 3998 linhas
CREATE TABLE IF NOT EXISTS raw."addresses" (
    "id" INTEGER NOT NULL,
    "customer_id" INTEGER NOT NULL,
    "address_type" TEXT NOT NULL,
    "postal_code" TEXT NOT NULL,
    "street" TEXT NOT NULL,
    "number" TEXT NOT NULL,
    "complement" TEXT,
    "district" TEXT NOT NULL,
    "city" TEXT NOT NULL,
    "state" TEXT NOT NULL,
    "country" TEXT NOT NULL,
    "is_primary" BOOLEAN NOT NULL,
    PRIMARY KEY ("id")
);

-- attributes.csv: 8 linhas
CREATE TABLE IF NOT EXISTS raw."attributes" (
    "id" INTEGER NOT NULL,
    "name" TEXT NOT NULL,
    "data_type" TEXT NOT NULL,
    PRIMARY KEY ("id")
);

-- brands.csv: 12 linhas
CREATE TABLE IF NOT EXISTS raw."brands" (
    "id" INTEGER NOT NULL,
    "name" TEXT NOT NULL,
    "country" TEXT,
    "is_active" BOOLEAN NOT NULL,
    "created_at" TIMESTAMP NOT NULL,
    "updated_at" TIMESTAMP NOT NULL,
    PRIMARY KEY ("id")
);

-- categories.csv: 14 linhas
CREATE TABLE IF NOT EXISTS raw."categories" (
    "id" INTEGER NOT NULL,
    "name" TEXT NOT NULL,
    "slug" TEXT NOT NULL,
    "parent_category_id" INTEGER,
    "is_active" BOOLEAN NOT NULL,
    "created_at" TIMESTAMP NOT NULL,
    "updated_at" TIMESTAMP NOT NULL,
    PRIMARY KEY ("id")
);

-- customers.csv: 2000 linhas
CREATE TABLE IF NOT EXISTS raw."customers" (
    "id" INTEGER NOT NULL,
    "person_type" TEXT NOT NULL,
    "legal_name" TEXT NOT NULL,
    "trade_name" TEXT,
    "tax_id" TEXT NOT NULL,
    "state_registration" TEXT,
    "email" TEXT,
    "phone" TEXT,
    "is_active" BOOLEAN NOT NULL,
    "created_at" TIMESTAMP NOT NULL,
    "updated_at" TIMESTAMP NOT NULL,
    PRIMARY KEY ("id")
);

-- employees.csv: 15 linhas
CREATE TABLE IF NOT EXISTS raw."employees" (
    "id" INTEGER NOT NULL,
    "full_name" TEXT NOT NULL,
    "cpf" TEXT NOT NULL,
    "email" TEXT NOT NULL,
    "role" TEXT NOT NULL,
    "primary_location_id" INTEGER NOT NULL,
    "hire_date" DATE NOT NULL,
    "termination_date" DATE,
    "is_active" BOOLEAN NOT NULL,
    "created_at" TIMESTAMP NOT NULL,
    "updated_at" TIMESTAMP NOT NULL,
    PRIMARY KEY ("id")
);

-- fiscal_invoices.csv: 34365 linhas
CREATE TABLE IF NOT EXISTS raw."fiscal_invoices" (
    "id" INTEGER NOT NULL,
    "order_id" INTEGER NOT NULL,
    "nfe_number" TEXT NOT NULL,
    "nfe_access_key" TEXT NOT NULL,
    "series" TEXT NOT NULL,
    "issued_at" TIMESTAMP NOT NULL,
    "status" TEXT NOT NULL,
    "total_amount" NUMERIC(8, 2) NOT NULL,
    "xml_storage_uri" TEXT NOT NULL,
    "created_at" TIMESTAMP NOT NULL,
    "updated_at" TIMESTAMP NOT NULL,
    PRIMARY KEY ("id")
);

-- goods_receipt_items.csv: 4733 linhas
CREATE TABLE IF NOT EXISTS raw."goods_receipt_items" (
    "id" INTEGER NOT NULL,
    "goods_receipt_id" INTEGER NOT NULL,
    "purchase_order_item_id" INTEGER NOT NULL,
    "quantity_received" NUMERIC(5, 3) NOT NULL,
    PRIMARY KEY ("id")
);

-- goods_receipts.csv: 1548 linhas
CREATE TABLE IF NOT EXISTS raw."goods_receipts" (
    "id" INTEGER NOT NULL,
    "purchase_order_id" INTEGER NOT NULL,
    "received_by_employee_id" INTEGER NOT NULL,
    "received_at" TIMESTAMP NOT NULL,
    "notes" TEXT,
    "created_at" TIMESTAMP NOT NULL,
    PRIMARY KEY ("id")
);

-- locations.csv: 6 linhas
CREATE TABLE IF NOT EXISTS raw."locations" (
    "id" INTEGER NOT NULL,
    "name" TEXT NOT NULL,
    "location_type" TEXT NOT NULL,
    "postal_code" TEXT NOT NULL,
    "street" TEXT NOT NULL,
    "number" TEXT NOT NULL,
    "complement" TEXT,
    "district" TEXT NOT NULL,
    "city" TEXT NOT NULL,
    "state" TEXT NOT NULL,
    "country" TEXT NOT NULL,
    "is_active" BOOLEAN NOT NULL,
    "created_at" TIMESTAMP NOT NULL,
    "updated_at" TIMESTAMP NOT NULL,
    PRIMARY KEY ("id")
);

-- order_items.csv: 147320 linhas
CREATE TABLE IF NOT EXISTS raw."order_items" (
    "id" INTEGER NOT NULL,
    "order_id" INTEGER NOT NULL,
    "product_variant_id" INTEGER NOT NULL,
    "quantity" INTEGER NOT NULL,
    "unit_price" NUMERIC(6, 2) NOT NULL,
    "icms_rate" NUMERIC(4, 2) NOT NULL,
    "ipi_rate" NUMERIC(4, 2) NOT NULL,
    "line_total" NUMERIC(7, 2) NOT NULL,
    PRIMARY KEY ("id")
);

-- orders.csv: 48998 linhas
CREATE TABLE IF NOT EXISTS raw."orders" (
    "id" INTEGER NOT NULL,
    "order_number" TEXT NOT NULL,
    "channel" TEXT NOT NULL,
    "customer_id" INTEGER NOT NULL,
    "salesperson_id" INTEGER,
    "location_id" INTEGER NOT NULL,
    "status" TEXT NOT NULL,
    "subtotal" NUMERIC(8, 2) NOT NULL,
    "discount_amount" NUMERIC(7, 2) NOT NULL,
    "total" NUMERIC(8, 2) NOT NULL,
    "placed_at" TIMESTAMP NOT NULL,
    "created_at" TIMESTAMP NOT NULL,
    "updated_at" TIMESTAMP NOT NULL,
    PRIMARY KEY ("id")
);

-- payments.csv: 53546 linhas
CREATE TABLE IF NOT EXISTS raw."payments" (
    "id" INTEGER NOT NULL,
    "order_id" INTEGER NOT NULL,
    "method" TEXT NOT NULL,
    "installments" INTEGER NOT NULL,
    "amount" NUMERIC(8, 2) NOT NULL,
    "status" TEXT NOT NULL,
    "paid_at" TIMESTAMP,
    "created_at" TIMESTAMP NOT NULL,
    "updated_at" TIMESTAMP NOT NULL,
    PRIMARY KEY ("id")
);

-- product_suppliers.csv: 1520 linhas
CREATE TABLE IF NOT EXISTS raw."product_suppliers" (
    "product_variant_id" INTEGER NOT NULL,
    "supplier_id" INTEGER NOT NULL,
    "supplier_sku" TEXT,
    "last_quoted_cost" NUMERIC(6, 2) NOT NULL,
    "lead_time_days" INTEGER NOT NULL,
    "is_preferred" BOOLEAN NOT NULL,
    "created_at" TIMESTAMP NOT NULL,
    "updated_at" TIMESTAMP NOT NULL
);

-- product_variants.csv: 1009 linhas
CREATE TABLE IF NOT EXISTS raw."product_variants" (
    "id" INTEGER NOT NULL,
    "product_id" INTEGER NOT NULL,
    "sku" TEXT NOT NULL,
    "barcode_ean" TEXT,
    "sale_price" NUMERIC(6, 2) NOT NULL,
    "cost_price" NUMERIC(6, 2) NOT NULL,
    "weight_kg" NUMERIC(5, 3) NOT NULL,
    "icms_rate" NUMERIC(4, 2) NOT NULL,
    "ipi_rate" NUMERIC(4, 2) NOT NULL,
    "is_active" BOOLEAN NOT NULL,
    "created_at" TIMESTAMP NOT NULL,
    "updated_at" TIMESTAMP NOT NULL,
    PRIMARY KEY ("id")
);

-- products.csv: 500 linhas
CREATE TABLE IF NOT EXISTS raw."products" (
    "id" INTEGER NOT NULL,
    "name" TEXT NOT NULL,
    "description" TEXT,
    "brand_id" INTEGER NOT NULL,
    "category_id" INTEGER NOT NULL,
    "ncm_code" TEXT NOT NULL,
    "unit_of_measure" TEXT NOT NULL,
    "is_active" BOOLEAN NOT NULL,
    "created_at" TIMESTAMP NOT NULL,
    "updated_at" TIMESTAMP NOT NULL,
    PRIMARY KEY ("id")
);

-- purchase_order_items.csv: 6059 linhas
CREATE TABLE IF NOT EXISTS raw."purchase_order_items" (
    "id" INTEGER NOT NULL,
    "purchase_order_id" INTEGER NOT NULL,
    "product_variant_id" INTEGER NOT NULL,
    "quantity_ordered" INTEGER NOT NULL,
    "unit_cost" NUMERIC(6, 2) NOT NULL,
    "line_total" NUMERIC(8, 2) NOT NULL,
    PRIMARY KEY ("id")
);

-- purchase_orders.csv: 2000 linhas
CREATE TABLE IF NOT EXISTS raw."purchase_orders" (
    "id" INTEGER NOT NULL,
    "po_number" TEXT NOT NULL,
    "supplier_id" INTEGER NOT NULL,
    "buyer_id" INTEGER NOT NULL,
    "destination_location_id" INTEGER NOT NULL,
    "status" TEXT NOT NULL,
    "currency" TEXT NOT NULL,
    "subtotal" NUMERIC(8, 2) NOT NULL,
    "total" NUMERIC(8, 2) NOT NULL,
    "placed_at" TIMESTAMP NOT NULL,
    "expected_delivery_at" DATE,
    "created_at" TIMESTAMP NOT NULL,
    "updated_at" TIMESTAMP NOT NULL,
    PRIMARY KEY ("id")
);

-- return_items.csv: 1384 linhas
CREATE TABLE IF NOT EXISTS raw."return_items" (
    "id" INTEGER NOT NULL,
    "return_id" INTEGER NOT NULL,
    "order_item_id" INTEGER NOT NULL,
    "quantity" NUMERIC(5, 3) NOT NULL,
    "action" TEXT NOT NULL,
    "exchange_variant_id" INTEGER,
    "unit_refund_amount" NUMERIC(6, 2) NOT NULL,
    PRIMARY KEY ("id")
);

-- returns.csv: 980 linhas
CREATE TABLE IF NOT EXISTS raw."returns" (
    "id" INTEGER NOT NULL,
    "return_number" TEXT NOT NULL,
    "order_id" INTEGER NOT NULL,
    "customer_id" INTEGER NOT NULL,
    "received_at_location_id" INTEGER NOT NULL,
    "status" TEXT NOT NULL,
    "reason" TEXT,
    "total_refund_amount" NUMERIC(7, 2) NOT NULL,
    "created_at" TIMESTAMP NOT NULL,
    "updated_at" TIMESTAMP NOT NULL,
    PRIMARY KEY ("id")
);

-- stock_levels.csv: 6054 linhas
CREATE TABLE IF NOT EXISTS raw."stock_levels" (
    "product_variant_id" INTEGER NOT NULL,
    "location_id" INTEGER NOT NULL,
    "quantity_on_hand" NUMERIC(5, 3) NOT NULL,
    "reorder_point" TEXT,
    "updated_at" TIMESTAMP NOT NULL
);

-- stock_movements.csv: 115312 linhas
CREATE TABLE IF NOT EXISTS raw."stock_movements" (
    "id" INTEGER NOT NULL,
    "product_variant_id" INTEGER NOT NULL,
    "location_id" INTEGER NOT NULL,
    "movement_type" TEXT NOT NULL,
    "quantity" NUMERIC(6, 3) NOT NULL,
    "reference_table" TEXT,
    "reference_id" INTEGER,
    "employee_id" INTEGER,
    "notes" TEXT,
    "occurred_at" TIMESTAMP NOT NULL,
    "created_at" TIMESTAMP NOT NULL,
    PRIMARY KEY ("id")
);

-- suppliers.csv: 25 linhas
CREATE TABLE IF NOT EXISTS raw."suppliers" (
    "id" INTEGER NOT NULL,
    "legal_name" TEXT NOT NULL,
    "trade_name" TEXT,
    "country" TEXT NOT NULL,
    "tax_id" TEXT NOT NULL,
    "tax_id_type" TEXT NOT NULL,
    "email" TEXT NOT NULL,
    "phone" TEXT NOT NULL,
    "contact_name" TEXT NOT NULL,
    "is_active" BOOLEAN NOT NULL,
    "created_at" TIMESTAMP NOT NULL,
    "updated_at" TIMESTAMP NOT NULL,
    PRIMARY KEY ("id")
);

-- variant_attribute_values.csv: 2018 linhas
CREATE TABLE IF NOT EXISTS raw."variant_attribute_values" (
    "product_variant_id" INTEGER NOT NULL,
    "attribute_id" INTEGER NOT NULL,
    "value" TEXT NOT NULL
);
