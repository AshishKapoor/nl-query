#!/usr/bin/env bash
# =============================================================================
# NL-Query: Seed Data Verification Script
# =============================================================================
# Validates that seed data was loaded correctly into both databases.
#
# Prerequisites: docker compose up -d && databases are healthy
# Usage: ./scripts/seed-check.sh
# =============================================================================

set -euo pipefail

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PASSED=0
FAILED=0

check_count() {
    local label="$1"
    local expected="$2"
    local actual="$3"

    actual=$(echo "$actual" | tr -d '[:space:]')

    if [ "$actual" = "$expected" ]; then
        echo -e "  ${GREEN}✓${NC} $label: $actual rows"
        PASSED=$((PASSED + 1))
    else
        echo -e "  ${RED}✗${NC} $label: expected $expected, got $actual"
        FAILED=$((FAILED + 1))
    fi
}

echo -e "\n${BLUE}═══════════════════════════════════════════════${NC}"
echo -e "${BLUE}  Seed Data Verification${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════${NC}\n"

# ---------------------------------------------------------------------------
# Postgres checks
# ---------------------------------------------------------------------------
echo -e "${YELLOW}▸ PostgreSQL (retail)${NC}"

PG_DEPTS=$(docker exec nlq-postgres psql -U retail_admin -d retail -tAc "SELECT COUNT(*) FROM departments;")
check_count "departments" "4" "$PG_DEPTS"

PG_PRODUCTS=$(docker exec nlq-postgres psql -U retail_admin -d retail -tAc "SELECT COUNT(*) FROM products;")
check_count "products" "40" "$PG_PRODUCTS"

PG_CUSTOMERS=$(docker exec nlq-postgres psql -U retail_admin -d retail -tAc "SELECT COUNT(*) FROM customers;")
check_count "customers" "20" "$PG_CUSTOMERS"

PG_MAP=$(docker exec nlq-postgres psql -U retail_admin -d retail -tAc "SELECT COUNT(*) FROM user_department_map;")
check_count "user_department_map" "12" "$PG_MAP"

# Products per department
echo -e "\n${YELLOW}  Products per department:${NC}"
for dept in accessories electronics apparel home_garden; do
    count=$(docker exec nlq-postgres psql -U retail_admin -d retail -tAc "SELECT COUNT(*) FROM products WHERE department='$dept';")
    check_count "  products.$dept" "10" "$count"
done

# ---------------------------------------------------------------------------
# MySQL checks
# ---------------------------------------------------------------------------
echo -e "\n${YELLOW}▸ MySQL (inventory)${NC}"

MY_SALES=$(docker exec nlq-mysql mysql -u inventory_admin -pinventory_secret_2024 -D inventory -sNe "SELECT COUNT(*) FROM sales;" 2>/dev/null)
check_count "sales" "100" "$MY_SALES"

MY_SUPPLIERS=$(docker exec nlq-mysql mysql -u inventory_admin -pinventory_secret_2024 -D inventory -sNe "SELECT COUNT(*) FROM suppliers;" 2>/dev/null)
check_count "suppliers" "10" "$MY_SUPPLIERS"

MY_STOCK=$(docker exec nlq-mysql mysql -u inventory_admin -pinventory_secret_2024 -D inventory -sNe "SELECT COUNT(*) FROM warehouse_stock;" 2>/dev/null)
check_count "warehouse_stock" "40" "$MY_STOCK"

# Sales per department
echo -e "\n${YELLOW}  Sales per department:${NC}"
for dept in accessories electronics apparel home_garden; do
    count=$(docker exec nlq-mysql mysql -u inventory_admin -pinventory_secret_2024 -D inventory -sNe "SELECT COUNT(*) FROM sales WHERE department='$dept';" 2>/dev/null)
    check_count "  sales.$dept" "25" "$count"
done

# =============================================================================
# Summary
# =============================================================================
TOTAL=$((PASSED + FAILED))
echo -e "\n${BLUE}═══════════════════════════════════════════════${NC}"
echo -e "  Results: ${GREEN}$PASSED passed${NC}, ${RED}$FAILED failed${NC}, $TOTAL total"
echo -e "${BLUE}═══════════════════════════════════════════════${NC}"

if [ "$FAILED" -gt 0 ]; then
    echo -e "\n${RED}⚠ Some seed checks failed. Inspect database logs.${NC}\n"
    exit 1
else
    echo -e "\n${GREEN}✅ All seed data verified!${NC}\n"
    exit 0
fi
