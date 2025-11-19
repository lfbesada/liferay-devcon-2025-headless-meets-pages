#!/bin/bash

# =======================================================================
# SCRIPT TO MIGRATE LIFERAY SITE PAGES (GET & PUT)
# This script uses fixed, default ERCs and executes step-by-step
# after user confirmation (pressing ENTER).
# =======================================================================

clear # Clears the screen before starting script execution

# ANSI Color Codes (Using $'\033[...' for robust escape sequence embedding)
RED=$'\033[31m'
RESET=$'\033[0m'
BOLD=$'\033[1m'
NOBOLD=$'\033[0m'
GREEN=$'\033[32m'
YELLOW=$'\033[33m' # Color for emphasis in conclusion

# --- Configuration and Variables ---

# Fixed default values for Origin and Target Site ERCs
ORIGIN_SITE_ERC="OriginSite"
TARGET_SITE_ERC="TargetSite"

TEMP_BODY_FILE="page_full_body.json"
AUTH='test@liferay.com:test'
API_PATH="/o/headless-admin-site/v1.0/sites"
# Uses environment variable $PORTAL_URL or default value http://localhost:8080
PORTAL_URL="${PORTAL_URL:-http://localhost:8080}"

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
## SCRIPT INTRODUCTION
# ---------------------------------------------------------------------

echo "====================================================================="
echo "  [BULK PAGE MIGRATION OVERVIEW]"
echo "====================================================================="
echo ""
echo -e "This script is designed to migrate Site Pages from the ${BOLD}Origin Site${RESET} (${ORIGIN_SITE_ERC}) to the ${BOLD}Target Site${RESET} (${TARGET_SITE_ERC}) using the Site-Pages endpoints."
echo ""

# 1. GET Step Description
echo -e "ℹ️  Step 1: ${BOLD}Retrieve All Content${RESET}"
echo -e "    A **GET** request is made to the Origin Site to retrieve all pages, including their content (Page Specifications), using the ${BOLD}nestedFields=pageSpecifications${RESET} parameter."
echo -e "    ➡️ ${BOLD}Endpoint:${RESET} ${RED}${BOLD}${PORTAL_URL}${API_PATH}/${ORIGIN_SITE_ERC}/site-pages?nestedFields=pageSpecifications${RESET} (GET)"
echo ""

# 2. Migration Step Description
echo -e "ℹ️  Step 2: ${BOLD}Migrate Pages (PUT/POST)${RESET}"
echo -e "    Pages are imported into the Target Site. The script uses **PUT** for Content Pages (which supports Upsert) and **POST** for Widget Pages (as they are created if they don't exist). You could use PUT for both."
echo -e "    ➡️ PUT ${BOLD}Endpoint:${RESET} ${RED}${BOLD}${PORTAL_URL}${API_PATH}/${TARGET_SITE_ERC}/site-pages/{sitePageERC}${RESET}"
echo -e "    ➡️ POST ${BOLD}Endpoint:${RESET} ${RED}${BOLD}${PORTAL_URL}${API_PATH}/${TARGET_SITE_ERC}/site-pages${RESET}"
echo ""

wait_for_user

# --- Initialization Summary ---

echo "====================================================================="
echo "  STARTING BULK PAGE MIGRATION"
echo "====================================================================="
echo "---------------------------------------------------------------------"
echo ""

# ---------------------------------------------------------------------
## Step 1: GET ALL Site Pages from the Origin Site
# ---------------------------------------------------------------------
# Includes explanation of the action and the endpoint.
next_action "1. GET All Site Pages from Origin Site"
echo -e "ℹ️  ${BOLD}Action:${RESET} Retrieve the list of all Site Pages from the Origin site, using ${BOLD}nestedFields=pageSpecifications${RESET} to fetch the content simultaneously."
echo -e "ℹ️  ${BOLD}Endpoint:${RESET} ${RED}${BOLD}${PORTAL_URL}${API_PATH}/${ORIGIN_SITE_ERC}/site-pages?pageSize=-1&nestedFields=pageSpecifications${RESET}"

echo "====================================================================="
echo "  STARTING BULK PAGE EXPORT"
echo "====================================================================="
echo "---------------------------------------------------------------------"
echo ""

# Temporarily disable tracing mode for the curl command to hide the full JSON output
PAGES_LIST_JSON=$( { set +x; } 2>/dev/null; \
    curl -s -X 'GET' \
    "${PORTAL_URL}${API_PATH}/${ORIGIN_SITE_ERC}/site-pages?pageSize=-1&nestedFields=pageSpecifications" \
    -H 'X-Liferay-Accept-All-Languages: true' \
    -u "${AUTH}" )

# Check for successful retrieval and if the 'items' array exists
if ! echo "$PAGES_LIST_JSON" | jq -e '.items' > /dev/null; then
    echo "❌ ERROR: Could not retrieve page list or the JSON response is invalid."
    echo "Full response:"
    echo "$PAGES_LIST_JSON"
    exit 1
fi

echo "✅ EXECUTION COMPLETE: Successfully retrieved pages from ${ORIGIN_SITE_ERC}."

# Shorten the JSON output with ordered fields and '...':'...' syntax in both levels.
SHORTENED_PAGES_JSON=$(echo "$PAGES_LIST_JSON" | \
    jq '.items = [.items[] | {
        externalReferenceCode,
        name_i18n,
        pageSpecifications: (.pageSpecifications | map({
            externalReferenceCode
        } + if .draftContentPageSpecificationExternalReferenceCode != null then {draftContentPageSpecificationExternalReferenceCode} else {} end + {
            "...": "..."
        })),
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
## Step 3: Iterate and Migrate Each Page
# ---------------------------------------------------------------------
next_action "2. Start Iterative Import (PUT/POST each page to Target Site)"
echo "ℹ️  ${BOLD}Action:${RESET} Iterate through all pages to clean payload and update on Target site. This process ensures all content is transferred by relying on the initial fetch using the **nestedFields=pageSpecifications** parameter."
echo -e "ℹ️  ${BOLD}Endpoint:${RESET} ${RED}${BOLD}${PORTAL_URL}${API_PATH}/${TARGET_SITE_ERC}/site-pages/{pageErc}${RESET} (PUT for ContentPage, POST for WidgetPage)"

echo "====================================================================="
echo "  STARTING IMPORT LOOP"
echo "====================================================================="
echo "---------------------------------------------------------------------"
echo ""

# Loop through each ERC extracted
for PAGE_ERC in $PAGE_ERCS; do
    echo ""
    echo -e "--- Migrating Page: ${BOLD}${PAGE_ERC}${RESET} ---"

    # --- 3a & 3b: GET Specific Page Content & Clean JSON Payload (Silent) ---
    PAGE_BODY_JSON=$(echo "$PAGES_LIST_JSON" | jq -c --arg erc "$PAGE_ERC" '.items[] | select(.externalReferenceCode == $erc)')

    if [ -z "$PAGE_BODY_JSON" ] || [ "$PAGE_BODY_JSON" == "null" ]; then
        echo "   ❌ ERROR: Could not find page content in the initial list for ${PAGE_ERC}."
        continue
    fi

    CLEANED_BODY=$(echo "$PAGE_BODY_JSON" | \
        jq 'del(.id, .dateCreated, .dateModified, .creator, .lastModifier, .status, .url, .viewable)' | \
        jq 'if .type == null then .type = "Content" else . end')

    echo "$CLEANED_BODY" > "$TEMP_BODY_FILE"

    # Determine Page Type and set request method and target URL
    PAGE_TYPE=$(echo "$CLEANED_BODY" | jq -r '.type')
    REQUEST_METHOD="PUT"
    TARGET_URL="${PORTAL_URL}${API_PATH}/${TARGET_SITE_ERC}/site-pages/${PAGE_ERC}?nestedFields=pageSpecifications"

    if [ "$PAGE_TYPE" = "WidgetPage" ]; then
        REQUEST_METHOD="POST"
        # POST uses the base endpoint to create a new page, it doesn't use the page ERC in the URL path.
        TARGET_URL="${PORTAL_URL}${API_PATH}/${TARGET_SITE_ERC}/site-pages?nestedFields=pageSpecifications"
        echo "   ℹ️  Using POST to create/recreate page."
    else
        echo "   ℹ️  Using PUT to update page."
    fi

    # Display the endpoint that will be invoked for this specific page (in Red)
    echo -e "   ➡️ Invoking **${REQUEST_METHOD}** to endpoint: ${RED}${BOLD}${TARGET_URL}${RESET}"

    # Display the detailed payload sample before PUT/POST with ordered fields and '...':'...' syntax in both levels.
    echo "   📄 Using the following payload (JSON shortened):"
    echo "$CLEANED_BODY" | jq '{
        externalReferenceCode,
        name_i18n,
        pageSpecifications: (.pageSpecifications | map({
            externalReferenceCode
        } + if .draftContentPageSpecificationExternalReferenceCode != null then {draftContentPageSpecificationExternalReferenceCode} else {} end + {
            "...": "..."
        })),
        type,
        "...": "..."
    }'

    # --- 3c: PUT/POST the Page Object to the Target Site ---

    PUT_RESPONSE=$({ set +x; } 2>/dev/null; \
        curl -s -X "${REQUEST_METHOD}" \
        "${TARGET_URL}" \
        -d  @"${TEMP_BODY_FILE}" \
        -H 'Accept-Language: en-US' \
        -H 'Content-Type: application/json' \
        -u "${AUTH}" \
        -w 'SEPARATOR%{http_code}' )

    # Disable tracing mode for the rest of the loop
    { set +x; } 2>/dev/null

    RESPONSE_CODE="${PUT_RESPONSE#*SEPARATOR}"

    if [[ "$RESPONSE_CODE" =~ ^2 ]]; then
        echo "   🎉 SUCCESS: Page ${PAGE_ERC} updated/created on target site (${REQUEST_METHOD} HTTP ${RESPONSE_CODE})."
    else
        RESPONSE_BODY="${PUT_RESPONSE%SEPARATOR*}"
        echo "   🚨 FAILURE: ${REQUEST_METHOD} failed for ${PAGE_ERC} (HTTP ${RESPONSE_CODE})."
        echo "   Response Body (full error):"
        echo "$RESPONSE_BODY" | jq '.'
    fi

    # Pause added at the end of each iteration
    wait_for_user
done

# --- Cleanup (SILENT EXECUTION) ---
rm -f "$TEMP_BODY_FILE"

echo ""
echo "--- Script Execution Complete ---"

wait_for_user

clear

# echo -e "${BOLD}${GREEN}This highlights a key feature of the new Headless API:${RESET}"
# echo -e ""
# echo -e "With this new API, all content references are ${BOLD}optional${RESET}, and the import order does not matter:"
# echo -e ""
# echo -e "  • ${GREEN}Resilience:${RESET} Even though the Web Content reference did not exist in the target site, our page import did not fail."
# echo -e "  • ${GREEN}Automatic Synchronization:${RESET} When we later create that reference in the site (by importing or creating the referenced Web Content), the content will ${BOLD}automatically${RESET} display on the page without needing any further action for the page itself."
# echo -e ""

# echo "====================================================================="
# echo -e ""
# echo -e ${BOLD}"Once the reference exists in the site the content is now visible without any extra actions.${RESET}"
# echo "====================================================================="
