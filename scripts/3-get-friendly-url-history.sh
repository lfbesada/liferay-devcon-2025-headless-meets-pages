#!/bin/bash

# =======================================================================
# SCRIPT TO RETRIEVE FRIENDLY URL HISTORY FOR ALL SITE PAGES
# This script retrieves all pages from the target site, extracts page
# ERC and name, and then performs a GET request to the friendly-url-history
# endpoint for each page.
# =======================================================================

# ANSI Color Codes (Using $'\033[...' for robust escape sequence embedding)
RED=$'\033[31m'
RESET=$'\033[0m'
BOLD=$'\033[1m'
NOBOLD=$'\033[0m'
GREEN=$'\033[32m'
YELLOW=$'\033[33m' # Color for emphasis in conclusion

# -----------------------------------------------------------------------
# --- CONFIGURATION VARIABLES ---
# -----------------------------------------------------------------------

TARGET_SITE_ERC="TargetSite"

AUTH='test@liferay.com:test'
API_PATH="/o/headless-admin-site/v1.0/sites"
# Uses environment variable $PORTAL_URL or default value http://localhost:8080
PORTAL_URL="${PORTAL_URL:-http://localhost:8080}"


# --- Helper Function for Step-by-Step Execution ---

# Pauses the script and waits for the user to press ENTER
wait_for_user() {
    read -rp ""
}

# Displays the next action header
next_action() {
    echo ""
    echo "--- ${BOLD}NEXT Action:${RESET} $1 ---"
    echo ""
}

# ---------------------------------------------------------------------
## SCRIPT INTRODUCTION
# ---------------------------------------------------------------------

clear # Clear screen

echo "====================================================================="
echo "  [FRIENDLY URL HISTORY RETRIEVAL]"
echo "====================================================================="
echo ""
echo -e "By changing the content URLs in previous steps, we have enriched the ${BOLD}URL history${RESET}, which we can now access using the API."
echo ""

# 1. GET Step Description
echo -e "ℹ️  Step 1: ${BOLD}Retrieve All Pages${RESET}"
echo -e "    We perform a **GET** request for all pages of the target site (${TARGET_SITE_ERC}) to extract their ERCs."
echo -e "    ➡️ ${BOLD}Endpoint:${RESET} ${RED}${BOLD}${PORTAL_URL}${API_PATH}/${TARGET_SITE_ERC}/site-pages${RESET} (GET)"
echo ""

# 2. History Step Description
echo -e "ℹ️  Step 2: ${BOLD}Retrieve URL History${RESET}"
echo -e "    We will iterate through each page to retrieve its ${BOLD}Friendly URL History${RESET} using the dedicated endpoint."
echo -e "    ➡️ ${BOLD}Endpoint:${RESET} ${RED}${BOLD}${PORTAL_URL}${API_PATH}/${TARGET_SITE_ERC}/site-pages/{erc}/friendly-url-history${RESET} (GET)"
echo ""

wait_for_user

# --- Initialization Summary ---

clear # Clear screen to start execution

echo "====================================================================="
echo "  STARTING URL HISTORY RETRIEVAL"
echo "====================================================================="
echo "---------------------------------------------------------------------"
echo ""

# ---------------------------------------------------------------------
## Step 1: GET ALL Site Pages from the Target Site
# ---------------------------------------------------------------------
next_action "1. GET All Site Pages from Target Site"
echo "ℹ️  ${BOLD}Action:${RESET} Retrieve the list of all Site Pages from the target site (${TARGET_SITE_ERC})."
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
echo "✅ EXECUTION COMPLETE: Successfully retrieved ${BOLD}${TOTAL_PAGES}${RESET} pages from ${TARGET_SITE_ERC}."

# Shorten the JSON output for display (only key identification fields)
SHORTENED_PAGES_JSON=$(echo "$PAGES_LIST_JSON" | \
    jq '.items = [.items[] | {
        externalReferenceCode,
        name_i18n,
        friendlyUrlPath_i18n,
        "...": "..."
    }]' )

echo "📄 Preview of retrieved page data (JSON shortened):"
echo "$SHORTENED_PAGES_JSON" | jq '.'

wait_for_user


# ---------------------------------------------------------------------
## Step 2: Extract Page ERCs and Names (JSON objects, line separated) (SILENT EXECUTION)
# ---------------------------------------------------------------------
# Extract an array of JSON objects (erc, name) and store them in a Bash array.
mapfile -t PAGE_INFO_ARRAY < <(echo "$PAGES_LIST_JSON" | jq -r '.items[] | {
    erc: .externalReferenceCode,
    name: ."name_i18n"."en-US"
} | @json')

# Check if the array is populated
if [ ${#PAGE_INFO_ARRAY[@]} -eq 0 ]; then
    echo "❌ ERROR: No page information could be extracted from the GET response. Exiting."
    exit 1
fi


# ---------------------------------------------------------------------
## Step 3: Iterate and GET Friendly URL History
# ---------------------------------------------------------------------
next_action "2. Start Iterative URL History Retrieval"
echo "ℹ️  ${BOLD}Action:${RESET} Iterate through all pages to retrieve the Friendly URL History."
echo -e "ℹ️  ${BOLD}Endpoint:${RESET} ${RED}${BOLD}${PORTAL_URL}${API_PATH}/${TARGET_SITE_ERC}/site-pages/{erc}/friendly-url-history${RESET} (GET)"
wait_for_user

echo "====================================================================="
echo "  STARTING HISTORY RETRIEVAL LOOP"
echo "---------------------------------------------------------------------"

RETRIEVED_COUNT=0
FAILED_COUNT=0

# Loop through each item in the bash array
for PAGE_ITEM in "${PAGE_INFO_ARRAY[@]}"; do

    # Extract ERC and Name from the single-line JSON object using jq
    PAGE_ERC=$(echo "$PAGE_ITEM" | jq -r '.erc')
    PAGE_NAME=$(echo "$PAGE_ITEM" | jq -r '.name')

    # Apply color to the page name
    COLORED_PAGE_NAME="${BOLD}${PAGE_NAME}${RESET}"

    echo ""
    echo "--- Retrieving History for Page: ${COLORED_PAGE_NAME} (ERC: ${PAGE_ERC}) ---"

    # Determine Target URL for history GET
    REQUEST_METHOD="GET"
    TARGET_URL="${PORTAL_URL}${API_PATH}/${TARGET_SITE_ERC}/site-pages/${PAGE_ERC}/friendly-url-history"

    # Display the endpoint that will be invoked (in Red)
    echo -e "   ➡️ Invoking **${REQUEST_METHOD}** to endpoint: ${RED}${BOLD}${TARGET_URL}${RESET}"

    # --- 3b: GET the Friendly URL History ---

    # We run the entire assignment in a subshell with tracing disabled
    HISTORY_RESPONSE=$({ set +x; } 2>/dev/null; \
        curl -s -X "${REQUEST_METHOD}" \
        "${TARGET_URL}" \
        -H 'Accept-Language: en-US' \
        -H 'Content-Type: application/json' \
        -u "${AUTH}" \
        -w 'SEPARATOR%{http_code}' )

    # Disable tracing mode for the rest of the loop
    { set +x; } 2>/dev/null

    RESPONSE_CODE="${HISTORY_RESPONSE#*SEPARATOR}"
    RESPONSE_BODY="${HISTORY_RESPONSE%SEPARATOR*}"

    if [[ "$RESPONSE_CODE" =~ ^2 ]]; then
        echo -e "   🎉 ${GREEN}SUCCESS${RESET}: History retrieved for ${COLORED_PAGE_NAME} (HTTP ${RESPONSE_CODE})."
        echo "   📄 Response Body (JSON):"
        echo "$RESPONSE_BODY" | jq '.'
        RETRIEVED_COUNT=$((RETRIEVED_COUNT + 1))
    else
        echo -e "   🚨 ${RED}FAILURE${RESET}: ${REQUEST_METHOD} failed for ${COLORED_PAGE_NAME} (HTTP ${RESPONSE_CODE})."
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

# --- FINAL TIP ---

echo "====================================================================="
echo -e "   ${BOLD}${GREEN}COMPLETE URL VISIBILITY${RESET}"
echo "====================================================================="
echo -e ""
echo -e "This example demonstrates how the ${BOLD}Friendly URL History${RESET} endpoint provides full ${YELLOW}traceability and management${RESET} of your content URLs, even after multiple changes."
echo -e ""
echo -e "${BOLD}Key Points:${RESET}"
echo -e "  • ${GREEN}Versatility:${RESET} Friendly URL History is not only available for ${BOLD}Site Pages${RESET} (as in this example) but also for ${BOLD}Display Pages${RESET} and ${BOLD}Utility Pages${RESET}."
echo -e "  • ${GREEN}Flexible Access:${RESET} You can consume it in two ways:"
echo -e "    1. Using the dedicated direct endpoint (as we did: ${RED}.../friendly-url-history${RESET})."
echo -e "    2. Using the parameter ${BOLD}nestedFields=friendlyURLHistory${RESET} on the main page retrieval endpoints to get the history along with the rest of the page data in a single call."
echo -e ""

wait_for_user

echo "====================================================================="
echo -e ""
echo -e ${BOLD}"With this, you have complete control over the evolution of your site's URLs!${RESET}"
echo "====================================================================="