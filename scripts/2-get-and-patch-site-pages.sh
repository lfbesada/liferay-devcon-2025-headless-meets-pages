#!/bin/bash

# =======================================================================
# SCRIPT TO PERFORM BULK PATCH ON SITE PAGES
# This script retrieves all pages, extracts necessary data, and performs
# a single PATCH request per page to update:
# 1. Name and Friendly URL (based on MAPPING TABLE).
# 2. SEO HTML Title (based on formula).
# 3. hiddenFromNavigation (conditionally, if page type is WidgetPage).
# =======================================================================

# ANSI Color Codes
RED=$'\033[31m'
RESET=$'\033[0m'
GREEN=$'\033[32m'
BOLD=$'\033[1m'

# -----------------------------------------------------------------------
# --- CONFIGURATION VARIABLES ---
# -----------------------------------------------------------------------

TARGET_SITE_ERC="TargetSite"

TEMP_BODY_FILE="page_patch_body.json"
AUTH='test@liferay.com:test'
API_PATH="/o/headless-admin-site/v1.0/sites"
PORTAL_URL="${PORTAL_URL:-http://localhost:8080}"

# --- MAPPING TABLE (Name & URL Updates) ---
# ERC, New Name (en-US), New URL (en-US)
PAGE_UPDATE_MAP=$(cat <<EOF
0d11c04d-4721-386b-2dd9-346293e4b9e4,Moving Furniture,/moving-furniture
7f833c61-8461-8416-2d56-d475b0edd15d,Packing Items,/moving-items
978e9fb9-29d4-6499-8eb0-9c271ce3b399,Moving Day Tapas,/moving-day-tapas
EOF
)

# --- SEO CONFIGURATION (Formula for HTML Title) ---
SEO_PREFIX="[Liferay DevCon 2025] "
SEO_SUFFIX=" | Advanced SEO & Headless"


# --- Helper Functions for Step-by-Step Execution ---

wait_for_user() {
    read -rp "" # Waits for ENTER
}
# Displays the next action header
next_action() {
    echo ""
    echo "--- ${BOLD}NEXT Action:${RESET} $1 ---"
    echo ""
}

clear # Clear screen

# --- Initialization Summary ---

echo "====================================================================="
echo "  [BULK SITE PAGE UPDATE: SEO, NAME, AND URL]"
echo "  TARGET SITE: ${TARGET_SITE_ERC}"
echo "====================================================================="
echo ""
echo -e "In this script, we will use the site pages endpoints to modify some fields of our pages."
echo -e "   - Name"
echo -e "   - URL"
echo -e "   - HTMLTitle"
echo -e "   - Navigation menu visibility (conditionally)"
echo -e ""
echo -e "This script set the configured name and URL, and applies a formula to construct the ${BOLD}HTML Title${RESET} by adding a prefix and a suffix to the page name."
echo -e "It will also conditionally hide ${RED}Widget Pages${RESET} from the site navigation menu."
echo ""
echo -e "We will use Site-Pages GET and PATCH endpoints"
echo -e "The PATCH request will focus on modifying the ${BOLD}name_i18n${RESET}, the ${BOLD}friendlyUrlPath_i18n${RESET}, and the ${BOLD}pageSettings${RESET} fields."
echo ""
# 1. GET Step Description
echo -e "ℹ️  Step 1: ${BOLD}Retrieve Pages${RESET}"
echo -e "    We perform a **GET** of all site pages. We no longer use the ${BOLD}nestedFields${RESET} parameter since we don't need the page content."
echo -e "    ➡️ ${BOLD}Endpoint:${RESET} ${RED}${BOLD}${PORTAL_URL}${API_PATH}/TargetSite/site-pages${RESET} (GET)"
echo ""

# 2. PATCH Step Description
echo -e "ℹ️  Step 2: ${BOLD}Apply a combined PATCH to update SEO Title, Name, URL, and conditional navigation settings.${RESET}"
echo -e "    We will iterate over the pages using **PATCH** to modify the en-US translations of the name and the URL."
echo -e "    Also modifying the pageSettings for each page to:"
echo -e "   - Add the ${BOLD}en-US HTML Title${RESET} translation using the formula (pageSettings.seoSettings.htmlTitle_i18n)."
echo -e "   - IF the page is a ${RED}WidgetPage${RESET}, set ${BOLD}pageSettings.hiddenFromNavigation${RESET} to true."
echo -e "    ➡️ ${BOLD}Endpoint:${RESET} ${RED}${BOLD}${PORTAL_URL}${API_PATH}/${TARGET_SITE_ERC}/site-pages/{erc}${RESET} (PATCH)"
echo ""
wait_for_user

# ---------------------------------------------------------------------
## Step 1: GET ALL Site Pages from the Target Site
# ---------------------------------------------------------------------
next_action "1. GET All Site Pages"
echo "ℹ️  Action: Retrieving list of all Site Pages to extract base data."
echo -e "ℹ️  Endpoint: ${RED}${BOLD}${PORTAL_URL}${API_PATH}/${TARGET_SITE_ERC}/site-pages?pageSize=-1${RESET}"
wait_for_user

# Capture JSON response
PAGES_LIST_JSON=$( { set +x; } 2>/dev/null; \
    curl -s -X 'GET' \
    "${PORTAL_URL}${API_PATH}/${TARGET_SITE_ERC}/site-pages?pageSize=-1" \
    -H 'X-Liferay-Accept-All-Languages: true' \
    -u "${AUTH}" )

# Check for successful retrieval
if ! echo "$PAGES_LIST_JSON" | jq -e '.items' > /dev/null; then
    echo "❌ ERROR: Could not retrieve page list or the JSON response is invalid."
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
## Step 2: Extract Page Info (SILENT EXECUTION)
# ---------------------------------------------------------------------

# Map all necessary fields (ERC, Name, PageType, and the existing PageSettings object)
mapfile -t PAGE_INFO_ARRAY < <(echo "$PAGES_LIST_JSON" | jq -r '.items[] | {
    erc: .externalReferenceCode,
    name: ."name_i18n"."en-US",
    pageSettings: .pageSettings,
    pageType: .type
} | @json')

if [ ${#PAGE_INFO_ARRAY[@]} -eq 0 ]; then
    echo "❌ ERROR: No page information could be extracted. Exiting."
    exit 1
fi

# ---------------------------------------------------------------------
## Step 3: Iterate and PATCH Each Page
# ---------------------------------------------------------------------
next_action "2. Start Iterative Combined PATCH"
echo "ℹ️  Action: Iterating through pages to apply SEO formula, URL update, and conditional hiding."
echo -e "ℹ️  Endpoint: ${RED}${BOLD}${PORTAL_URL}${API_PATH}/${TARGET_SITE_ERC}/site-pages/{erc}${RESET} (PATCH)"
wait_for_user

echo "====================================================================="
echo "  STARTING PATCH LOOP"
echo "====================================================================="
echo "---------------------------------------------------------------------"

# Loop through each item in the bash array
for PAGE_ITEM in "${PAGE_INFO_ARRAY[@]}"; do

    # 3a: Extract all required data from the array item
    PAGE_ERC=$(echo "$PAGE_ITEM" | jq -r '.erc')
    PAGE_NAME=$(echo "$PAGE_ITEM" | jq -r '.name')
    PAGE_SETTINGS_JSON=$(echo "$PAGE_ITEM" | jq -c '.pageSettings')
    PAGE_TYPE=$(echo "$PAGE_ITEM" | jq -r '.pageType')

    # Re-introducing BOLD formatting for the page name
    PAGE_DISPLAY_NAME="${BOLD}${PAGE_NAME}${RESET}"

    # Check for Name/URL mapping (Source A logic)
    MAP_ENTRY=$(echo "$PAGE_UPDATE_MAP" | grep "^${PAGE_ERC},")
    NEW_NAME=$(echo "$MAP_ENTRY" | cut -d ',' -f 2)
    NEW_URL=$(echo "$MAP_ENTRY" | cut -d ',' -f 3)

    # Calculate SEO Title (Source B logic)
    NEW_HTML_TITLE="${SEO_PREFIX}${NEW_NAME}${SEO_SUFFIX}"

    # --- 3b: Build MODIFIED_PAGE_SETTINGS_JSON (SEO Title + Hiding) ---

    # 1. Apply SEO HTML Title update (always run)
    MODIFIED_PAGE_SETTINGS=$(echo "$PAGE_SETTINGS_JSON" | jq \
        --arg html_title "$NEW_HTML_TITLE" \
        '.seoSettings.htmlTitle_i18n."en-US" = $html_title')

    # 2. Apply WidgetPage Hiding (conditional)
    if [ "${PAGE_TYPE}" = "WidgetPage" ]; then
        echo "   ⚙️ Conditional Logic: Hiding WidgetPage from navigation."
        MODIFIED_PAGE_SETTINGS=$(echo "$MODIFIED_PAGE_SETTINGS" | jq '. + {"hiddenFromNavigation": true}')
    fi

    # --- 3c: Construct the FINAL PATCH Payload (Combining PageSettings and Name/URL) ---

    # Start the payload with the modified pageSettings object
    PATCH_BODY=$(jq -n --argjson settings "$MODIFIED_PAGE_SETTINGS" '{"pageSettings": $settings}')

    # Conditionally add Name/URL if mapping was found
    if [ -n "$NEW_NAME" ] && [ -n "$NEW_URL" ]; then
        PATCH_BODY=$(echo "$PATCH_BODY" | jq \
            --arg name "$NEW_NAME" \
            --arg url "$NEW_URL" \
            '. + {
                "name_i18n": {"en-US": $name},
                "friendlyUrlPath_i18n": {"en-US": $url}
            }')
    fi

    echo ""
    echo -e "--- Processing Page: ${PAGE_DISPLAY_NAME} (ERC: ${PAGE_ERC}) ---"

    # Display endpoint
    echo -e "   ➡️ Invoking **PATCH** to endpoint: ${RED}${BOLD}${PORTAL_URL}${API_PATH}/${TARGET_SITE_ERC}/site-pages/${PAGE_ERC}${RESET}"

    # Display the full payload being sent
    echo "   📄 FINAL PATCH Payload (JSON):"
    echo "$PATCH_BODY" | jq '.'

    # Save the payload to a temporary file
    echo "$PATCH_BODY" > "$TEMP_BODY_FILE"

    # Send the PATCH request
    PATCH_RESPONSE=$({ set +x; } 2>/dev/null; \
        curl -s -X 'PATCH' \
        "${PORTAL_URL}${API_PATH}/${TARGET_SITE_ERC}/site-pages/${PAGE_ERC}" \
        -d  @"${TEMP_BODY_FILE}" \
        -H 'Content-Type: application/json' \
        -u "${AUTH}" \
        -w 'SEPARATOR%{http_code}' )

    # Disable tracing mode for the rest of the loop
    { set +x; } 2>/dev/null

    RESPONSE_CODE="${PATCH_RESPONSE#*SEPARATOR}"

    if [[ "$RESPONSE_CODE" =~ ^2 ]]; then
        echo "   🎉 SUCCESS: Combined PATCH applied (HTTP ${RESPONSE_CODE})."
    else
        RESPONSE_BODY="${PATCH_RESPONSE%SEPARATOR*}"
        echo "   🚨 FAILURE: PATCH failed (HTTP ${RESPONSE_CODE})."
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

# --- Final Message (No Summary) ---

echo "====================================================================="
echo ""
echo -e "This demonstrates the power of using ${BOLD}PATCH${RESET} requests to perform partial and massive updates on page fields."
echo -e "${BOLD}Automation through the API allows for efficient bulk management of content settings.${RESET}"
echo ""
echo "====================================================================="