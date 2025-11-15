#!/bin/bash

# =======================================================================
# SCRIPT TO UPDATE PAGE METADATA (Name & URL) on Target Site (PATCH)
# This script retrieves all pages from the target site and updates
# name_i18n and friendlyUrlPath_i18n for a specific set of pages using PATCH.
# =======================================================================

clear # Clears the screen before starting script execution

# ANSI Color Codes
RED=$'\033[31m'
RESET=$'\033[0m'
BOLD=$'\033[1m'
NOBOLD=$'\033[0m'
GREEN=$'\033[32m'

# -----------------------------------------------------------------------
# --- CONFIGURATION VARIABLES ---
# -----------------------------------------------------------------------

# Target Site External Reference Code (ERC)
TARGET_SITE_ERC="TargetSite"

TEMP_BODY_FILE="page_patch_body.json"
AUTH='test@liferay.com:test'
API_PATH="/o/headless-admin-site/v1.0/sites"
# Uses environment variable $PORTAL_URL or default value http://localhost:8080
PORTAL_URL="${PORTAL_URL:-http://localhost:8080}"

# MAPPING TABLE: ERC, New Name (en-US), New URL (en-US)
# Add or remove lines in this block to easily manage the pages to be updated.
PAGE_UPDATE_MAP=$(cat <<EOF
0d11c04d-4721-386b-2dd9-346293e4b9e4,Moving Furniture,/moving-furniture
7f833c61-8461-8416-2d56-d475b0edd15d,Packing Items,/moving-items
978e9fb9-29d4-6499-8eb0-9c271ce3b399,Moving Day Tapas,/moving-day-tapas
EOF
)

# --- Helper Functions for Step-by-Step Execution ---

# Pauses the script and waits for the user to press ENTER
wait_for_user() {
    read -rp ""
}
# Displays the next action header
next_action() {
    echo ""
    echo "--- ${BOLD}NEXT ${BOLD}Action:${RESET}${RESET} $1 ---"
    echo ""
}

# ---------------------------------------------------------------------
## SCRIPT INTRODUCTION (ENGLISH)
# ---------------------------------------------------------------------

echo "====================================================================="
echo "  [PAGE NAME AND URL UPDATE OVERVIEW]"
echo "====================================================================="
echo ""
echo -e "In this script, we will use the site pages endpoints to modify the name and URL of our pages."
echo ""

# 1. GET Step Description
echo -e "ℹ️  Step 1: ${BOLD}Retrieve Pages${RESET}"
echo -e "    We perform a **GET** of all site pages. We no longer use the ${BOLD}nestedFields${RESET} parameter since we don't need the page content."
echo -e "    ➡️ ${BOLD}Endpoint:${RESET} ${RED}${BOLD}${PORTAL_URL}${API_PATH}/TargetSite/site-pages${RESET} (GET)"
echo ""

# 2. Migration Step Description
echo -e "ℹ️  Step 2: ${BOLD}Update Name and URL with PATCH${RESET}"
echo -e "    We will iterate over the pages using **PATCH** to modify the en-US translations of the name and the URL, according to SEO recommendations."
echo -e "    ➡️ ${BOLD}Endpoint:${RESET} ${RED}${BOLD}${PORTAL_URL}${API_PATH}/TargetSite/site-pages/{sitePageERC}${RESET} (PATCH)"
echo ""

wait_for_user

# --- Initialization Summary ---

echo "====================================================================="
echo "  STARTING PAGE NAME AND URL UPDATE ON ${TARGET_SITE_ERC} (PATCH)"
echo "====================================================================="
echo "---------------------------------------------------------------------"
echo ""

# ---------------------------------------------------------------------
## Step 1: GET ALL Site Pages from the Target Site
# ---------------------------------------------------------------------
# Includes explanation of the action and the endpoint.
next_action "1. GET All Site Pages from Target Site"
echo "ℹ️  ${BOLD}Action:${RESET} Retrieve the list of all Site Pages from the Target site to prepare for PATCH."
echo -e "ℹ️  ${BOLD}Endpoint:${RESET} ${RED}${BOLD}${PORTAL_URL}${API_PATH}/${TARGET_SITE_ERC}/site-pages?pageSize=-1${RESET}"
wait_for_user

# Temporarily disable tracing mode for the curl command to hide the full JSON output
PAGES_LIST_JSON=$( { set +x; } 2>/dev/null; \
    curl -s -X 'GET' \
    "${PORTAL_URL}${API_PATH}/${TARGET_SITE_ERC}/site-pages?pageSize=-1" \
    -H 'X-Liferay-Accept-All-Languages: true' \
    -u "${AUTH}" )

# Check for successful retrieval and if the 'items' array exists
if ! echo "$PAGES_LIST_JSON" | jq -e '.items' > /dev/null; then
    echo "❌ ERROR: Could not retrieve page list or the JSON response is invalid."
    echo "Full response:"
    echo "$PAGES_LIST_JSON"
    exit 1
fi

TOTAL_PAGES=$(echo "$PAGES_LIST_JSON" | jq '.totalCount')
echo "✅ EXECUTION COMPLETE: Successfully retrieved ${TOTAL_PAGES} pages from ${TARGET_SITE_ERC}."

# Shorten the JSON output, ordered fields, including friendlyUrlPath_i18n.
SHORTENED_PAGES_JSON=$(echo "$PAGES_LIST_JSON" | \
    jq '.items = [.items[] | {
        externalReferenceCode,
        name_i18n,
        friendlyUrlPath_i18n,
        type,
        "...": "..."
    }]' )

echo "📄 Response overview (JSON shortened):"
echo "$SHORTENED_PAGES_JSON" | jq '.'

wait_for_user


# ---------------------------------------------------------------------
## Step 2: Extract Page ERCs (SILENT EXECUTION)
# ---------------------------------------------------------------------

# Extract all externalReferenceCode values from the 'items' array
PAGE_ERCS=$(echo "$PAGES_LIST_JSON" | jq -r '.items[] | .externalReferenceCode')

if [ -z "$PAGE_ERCS" ]; then
    echo "❌ ERROR: No page External Reference Codes found. Exiting."
    exit 1
fi

# ---------------------------------------------------------------------
## Step 3: Iterate and PATCH Each Page
# ---------------------------------------------------------------------
next_action "2. Start Iterative Update (PATCH each page)"
echo "ℹ️  ${BOLD}Action:${RESET} Iterate through all pages and PATCH name and URL using hardcoded values based on ERC."
echo -e "ℹ️  ${BOLD}Endpoint:${RESET} ${RED}${BOLD}${PORTAL_URL}${API_PATH}/${TARGET_SITE_ERC}/site-pages/{pageErc}${RESET} (PATCH)"
wait_for_user

echo "====================================================================="
echo "  STARTING PATCH LOOP"
echo "====================================================================="
echo "---------------------------------------------------------------------"

UPDATED_COUNT=0
FAILED_COUNT=0

# Loop through each ERC extracted
for PAGE_ERC in $PAGE_ERCS; do
    echo ""
    echo -e "--- Processing Page: ${BOLD}${PAGE_ERC}${RESET} ---"

    # --- 3a: Check and extract new values from the configuration map ---

    # Use grep to find the line matching the current PAGE_ERC and cut to extract values
    MAP_ENTRY=$(echo "$PAGE_UPDATE_MAP" | grep "^${PAGE_ERC},")

    if [ -z "$MAP_ENTRY" ]; then
        echo "   ℹ️ INFO: No specific update defined for page ERC ${PAGE_ERC}. Skipping PATCH."
        continue # Skip to the next iteration
    fi

    # Extract NEW_NAME (2nd field) and NEW_URL (3rd field) using cut
    NEW_NAME=$(echo "$MAP_ENTRY" | cut -d ',' -f 2)
    NEW_URL=$(echo "$MAP_ENTRY" | cut -d ',' -f 3)

    # --- 3b: Construct the minimal PATCH payload with the new values ---
    # We use jq -n (null input) to construct the JSON from scratch using shell variables.
    PATCH_BODY=$(jq -n \
        --arg name "$NEW_NAME" \
        --arg url "$NEW_URL" \
        '{
            name_i18n: { "en-US": $name },
            friendlyUrlPath_i18n: { "en-US": $url }
        }')

    # Save the minimal payload to a temporary file
    echo "$PATCH_BODY" > "$TEMP_BODY_FILE"

    # Determine Target URL for PATCH
    REQUEST_METHOD="PATCH"
    TARGET_URL="${PORTAL_URL}${API_PATH}/${TARGET_SITE_ERC}/site-pages/${PAGE_ERC}"

    # Display the endpoint that will be invoked (in Red)
    echo -e "   ➡️ Invoking **${REQUEST_METHOD}** to endpoint: ${RED}${BOLD}${TARGET_URL}${RESET}"

    # Display the payload sample (minimal content: name and URL), ordered fields.
    echo "   📄 PATCHing the following payload (JSON):"
    echo "$PATCH_BODY" | jq '.'

    # --- 3c: PATCH the Page Object to the Target Site ---

    # We run the entire assignment in a subshell with tracing disabled
    PATCH_RESPONSE=$({ set +x; } 2>/dev/null; \
        curl -s -X "${REQUEST_METHOD}" \
        "${TARGET_URL}" \
        -d  @"${TEMP_BODY_FILE}" \
        -H 'Accept-Language: en-US' \
        -H 'Content-Type: application/json' \
        -u "${AUTH}" \
        -w 'SEPARATOR%{http_code}' )

    # Disable tracing mode for the rest of the loop
    { set +x; } 2>/dev/null

    RESPONSE_CODE="${PATCH_RESPONSE#*SEPARATOR}"

    if [[ "$RESPONSE_CODE" =~ ^2 ]]; then
        echo "   🎉 SUCCESS: Page ${PAGE_ERC} updated on target site (${REQUEST_METHOD} HTTP ${RESPONSE_CODE})."
        UPDATED_COUNT=$((UPDATED_COUNT + 1))
    else
        RESPONSE_BODY="${PATCH_RESPONSE%SEPARATOR*}"
        echo "   🚨 FAILURE: ${REQUEST_METHOD} failed for ${PAGE_ERC} (HTTP ${RESPONSE_CODE})."
        echo "   Response Body (full error):"
        echo "$RESPONSE_BODY" | jq '.'
        FAILED_COUNT=$((FAILED_COUNT + 1))
    fi

    # Pause added at the end of each iteration
    wait_for_user
done

echo ""
echo "--- Script Execution Complete ---"

wait_for_user

clear

# --- Final Message (No Summary) ---

echo "====================================================================="
echo -e "✅ SEO Name and URL Bulk Update Complete"
echo -e "---------------------------------------------------------------------"
echo -e "This massive operation, utilizing the power of the REST API, has successfully enhanced the SEO names and friendly URLs for all targeted site pages."
echo -e "We can now verify that the new Name and URL have been applied across the site. The API truly simplifies bulk changes!"
echo "====================================================================="

# --- Cleanup (SILENT EXECUTION) ---
rm -f "$TEMP_BODY_FILE"