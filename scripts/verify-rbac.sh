#!/usr/bin/env bash
# =============================================================================
# NL-Query: RBAC Verification Script
# =============================================================================
# Verifies that Trino's file-based access control correctly enforces:
#   1. Department-level row filtering on products/sales
#   2. PII column masking on customers
#   3. Cross-catalog queries work
#   4. Admin sees all data unmasked
#
# Prerequisites: docker compose up -d && Trino is healthy
# Usage: ./scripts/verify-rbac.sh
# =============================================================================

set -euo pipefail

TRINO_HOST="${TRINO_HOST:-localhost}"
TRINO_PORT="${TRINO_PORT:-8080}"
TRINO_PASSWORD="${TRINO_PASSWORD:-test123}"
PASSED=0
FAILED=0
TOTAL=0

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# ---------------------------------------------------------------------------
# Helper: run a query as a specific user
# ---------------------------------------------------------------------------
trino_query() {
    local user="$1"
    local sql="$2"
    docker exec nlq-trino trino --user "$user" --password --execute "$sql" 2>/dev/null <<< "$TRINO_PASSWORD" || true
}

# ---------------------------------------------------------------------------
# Helper: assert condition
# ---------------------------------------------------------------------------
assert_equals() {
    local test_name="$1"
    local expected="$2"
    local actual="$3"
    TOTAL=$((TOTAL + 1))

    if [ "$expected" = "$actual" ]; then
        echo -e "  ${GREEN}✓ PASS${NC}: $test_name"
        PASSED=$((PASSED + 1))
    else
        echo -e "  ${RED}✗ FAIL${NC}: $test_name"
        echo -e "    Expected: ${YELLOW}$expected${NC}"
        echo -e "    Actual:   ${YELLOW}$actual${NC}"
        FAILED=$((FAILED + 1))
    fi
}

assert_greater_than() {
    local test_name="$1"
    local threshold="$2"
    local actual="$3"
    TOTAL=$((TOTAL + 1))

    if [ "$actual" -gt "$threshold" ] 2>/dev/null; then
        echo -e "  ${GREEN}✓ PASS${NC}: $test_name (got $actual)"
        PASSED=$((PASSED + 1))
    else
        echo -e "  ${RED}✗ FAIL${NC}: $test_name"
        echo -e "    Expected: > ${YELLOW}$threshold${NC}"
        echo -e "    Actual:   ${YELLOW}$actual${NC}"
        FAILED=$((FAILED + 1))
    fi
}

assert_contains() {
    local test_name="$1"
    local expected_substr="$2"
    local actual="$3"
    TOTAL=$((TOTAL + 1))

    if echo "$actual" | grep -q "$expected_substr"; then
        echo -e "  ${GREEN}✓ PASS${NC}: $test_name"
        PASSED=$((PASSED + 1))
    else
        echo -e "  ${RED}✗ FAIL${NC}: $test_name"
        echo -e "    Expected to contain: ${YELLOW}$expected_substr${NC}"
        echo -e "    Actual:              ${YELLOW}$actual${NC}"
        FAILED=$((FAILED + 1))
    fi
}

# =============================================================================
echo -e "\n${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  NL-Query RBAC Verification Suite${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}\n"

# ---------------------------------------------------------------------------
# Test 1: Department Isolation — Products
# ---------------------------------------------------------------------------
echo -e "${YELLOW}▸ Test Group 1: Department Isolation (Products)${NC}"

# Accessories manager sees ONLY accessories products
ACC_PRODUCTS=$(trino_query "accessories_mgr" \
    "SELECT COUNT(*) FROM postgres_retail.public.products WHERE department = 'accessories'" | tr -d '"' | xargs)
assert_greater_than "accessories_mgr sees accessories products" 0 "$ACC_PRODUCTS"

ACC_ELEC=$(trino_query "accessories_mgr" \
    "SELECT COUNT(*) FROM postgres_retail.public.products WHERE department = 'electronics'" | tr -d '"' | xargs)
assert_equals "accessories_mgr sees 0 electronics products" "0" "$ACC_ELEC"

# Electronics manager sees ONLY electronics products
ELEC_PRODUCTS=$(trino_query "electronics_mgr" \
    "SELECT COUNT(*) FROM postgres_retail.public.products WHERE department = 'electronics'" | tr -d '"' | xargs)
assert_greater_than "electronics_mgr sees electronics products" 0 "$ELEC_PRODUCTS"

ELEC_ACC=$(trino_query "electronics_mgr" \
    "SELECT COUNT(*) FROM postgres_retail.public.products WHERE department = 'accessories'" | tr -d '"' | xargs)
assert_equals "electronics_mgr sees 0 accessories products" "0" "$ELEC_ACC"

# ---------------------------------------------------------------------------
# Test 2: Department Isolation — Sales (MySQL)
# ---------------------------------------------------------------------------
echo -e "\n${YELLOW}▸ Test Group 2: Department Isolation (Sales — MySQL)${NC}"

ACC_SALES=$(trino_query "accessories_mgr" \
    "SELECT COUNT(*) FROM mysql_inventory.inventory.sales WHERE department = 'accessories'" | tr -d '"' | xargs)
assert_greater_than "accessories_mgr sees accessories sales" 0 "$ACC_SALES"

ACC_ELEC_SALES=$(trino_query "accessories_mgr" \
    "SELECT COUNT(*) FROM mysql_inventory.inventory.sales WHERE department = 'electronics'" | tr -d '"' | xargs)
assert_equals "accessories_mgr sees 0 electronics sales" "0" "$ACC_ELEC_SALES"

# ---------------------------------------------------------------------------
# Test 3: Admin sees everything
# ---------------------------------------------------------------------------
echo -e "\n${YELLOW}▸ Test Group 3: Admin Full Access${NC}"

ADMIN_ALL_PRODUCTS=$(trino_query "data_admin" \
    "SELECT COUNT(*) FROM postgres_retail.public.products" | tr -d '"' | xargs)
assert_equals "data_admin sees all 40 products" "40" "$ADMIN_ALL_PRODUCTS"

ADMIN_ALL_SALES=$(trino_query "data_admin" \
    "SELECT COUNT(*) FROM mysql_inventory.inventory.sales" | tr -d '"' | xargs)
assert_equals "data_admin sees all 100 sales" "100" "$ADMIN_ALL_SALES"

# ---------------------------------------------------------------------------
# Test 4: Analyst sees everything (no row filter)
# ---------------------------------------------------------------------------
echo -e "\n${YELLOW}▸ Test Group 4: Analyst Full Read Access${NC}"

ANALYST_PRODUCTS=$(trino_query "merch_analyst" \
    "SELECT COUNT(*) FROM postgres_retail.public.products" | tr -d '"' | xargs)
assert_equals "merch_analyst sees all 40 products" "40" "$ANALYST_PRODUCTS"

# ---------------------------------------------------------------------------
# Test 5: PII Column Masking
# ---------------------------------------------------------------------------
echo -e "\n${YELLOW}▸ Test Group 5: PII Column Masking${NC}"

# Department manager should see masked email
ACC_EMAIL=$(trino_query "accessories_mgr" \
    "SELECT email FROM postgres_retail.public.customers LIMIT 1" | tr -d '"' | xargs)
assert_contains "accessories_mgr sees masked email" "***@***.***" "$ACC_EMAIL"

# Department manager should see masked phone
ACC_PHONE=$(trino_query "accessories_mgr" \
    "SELECT phone FROM postgres_retail.public.customers LIMIT 1" | tr -d '"' | xargs)
assert_contains "accessories_mgr sees masked phone" "XXX-XXXX" "$ACC_PHONE"

# Admin should see real email
ADMIN_EMAIL=$(trino_query "data_admin" \
    "SELECT email FROM postgres_retail.public.customers LIMIT 1" | tr -d '"' | xargs)
assert_contains "data_admin sees real email" "@email.com" "$ADMIN_EMAIL"

# ---------------------------------------------------------------------------
# Test 6: Cross-Catalog Join
# ---------------------------------------------------------------------------
echo -e "\n${YELLOW}▸ Test Group 6: Cross-Catalog Join (Postgres ↔ MySQL)${NC}"

CROSS_JOIN=$(trino_query "data_admin" \
    "SELECT COUNT(*) FROM mysql_inventory.inventory.sales s JOIN postgres_retail.public.products p ON s.sku = p.sku" | tr -d '"' | xargs)
assert_greater_than "Cross-catalog join returns results" 0 "$CROSS_JOIN"

# =============================================================================
# Summary
# =============================================================================
echo -e "\n${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "  Results: ${GREEN}$PASSED passed${NC}, ${RED}$FAILED failed${NC}, $TOTAL total"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"

if [ "$FAILED" -gt 0 ]; then
    echo -e "\n${RED}⚠ Some tests failed. Check RBAC configuration.${NC}\n"
    exit 1
else
    echo -e "\n${GREEN}✅ All RBAC tests passed!${NC}\n"
    exit 0
fi
