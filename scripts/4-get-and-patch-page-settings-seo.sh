#!/bin/bash

# =======================================================================
# SCRIPT TO GET AND RE-PATCH PAGE SETTINGS (BULK RESAVE)
# This script retrieves all pages from the target site, extracts ERC,
# name, pageSettings, and the page 'type'. It then performs a conditional
# PATCH request:
# 1. Sets the page name (with SEO prefix/suffix) as the SEO HTML Title.
# 2. IF pageType is "WidgetPage", sets hiddenFromNavigation to TRUE
#    *INSIDE* the pageSettings object.
# =======================================================================

# ANSI Color Codes
# Defining colors and bold style
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
# Uses environment variable $PORTAL_URL or default value http://localhost:8080
PORTAL_URL="${PORTAL_URL:-http://localhost:8080}"

# --- SEO CONFIGURATION ---
# Prefix and Suffix to improve SEO and provide context for the demo
SEO_PREFIX="[Liferay DevCon 2025] "
SEO_SUFFIX=" | Advanced SEO & Headless"


# --- Helper Functions for Step-by-Step Execution ---

wait_for_user() {
    read -rp ""
}

# Displays the next action header
next_action() {
    echo ""
    echo "--- ${BOLD}NEXT Action:${RESET} $1 ---"
    echo ""
}

clear # Clear screen

echo "====================================================================="
echo "  [PAGE SETTINGS GET AND PATCH]"
echo "====================================================================="
echo ""
echo -e "This script applies a formula to construct the ${BOLD}HTML Title${RESET} by adding a prefix and a suffix to the page name."
echo -e "It will also conditionally hide ${RED}Widget Pages${RESET} from the site navigation menu."
echo ""
echo -e "We will use the same Site-Pages GET and PATCH endpoints, but the PATCH request will focus on modifying the ${BOLD}pageSettings${RESET} field."
echo ""

# 1. GET Step Description
echo -e "ℹ️  Step 1: ${BOLD}Retrieve All Pages${RESET}"
echo -e "    We perform a **GET** request for all pages to extract their ERC, type, and the current page settings."
echo -e "    ➡️ ${BOLD}Endpoint:${RESET} ${RED}${BOLD}${PORTAL_URL}${API_PATH}/${TARGET_SITE_ERC}/site-pages${RESET} (GET)"
echo ""

# 2. History Step Description
echo -e "ℹ️  Step 2: ${BOLD}PATCH${RESET} pageSettings for each page to:"
echo -e "   - Add the ${BOLD}en-US HTML Title${RESET} translation using the formula (pageSettings.seoSettings.htmlTitle_i18n)."
echo -e "   - IF the page is a ${RED}WidgetPage${RESET}, set ${BOLD}pageSettings.hiddenFromNavigation${RESET} to true."
echo -e "    ➡️ ${BOLD}Endpoint:${RESET} ${RED}${BOLD}${PORTAL_URL}${API_PATH}/${TARGET_SITE_ERC}/site-pages/{erc}${RESET} (PATCH)"
echo ""

wait_for_user

# ---------------------------------------------------------------------
## Step 1: GET ALL Site Pages from the Target Site and Extract Data
# ---------------------------------------------------------------------
next_action "1. GET All Site Pages"
echo "ℹ️  Action: Retrieve the list of all Site Pages from the Target site, including pageSettings and page type."
# Using bold red for the endpoint URL
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

# ---------------------------------------------------------------------
## Step 2: Extract ERC, Name, pageSettings, and type (JSON objects, line separated)
# ---------------------------------------------------------------------

# mapfile -t populates the Bash array with line-separated, valid JSON objects.
mapfile -t PAGE_INFO_ARRAY < <(echo "$PAGES_LIST_JSON" | jq -r '.items[] | {
    erc: .externalReferenceCode,
    name: ."name_i18n"."en-US",
    pageSettings: .pageSettings,
    pageType: .type  # <-- Extracts the value of the 'type' field
} | @json')

if [ ${#PAGE_INFO_ARRAY[@]} -eq 0 ]; then
    echo "❌ ERROR: No page information could be extracted. Exiting."
    exit 1
fi


# ---------------------------------------------------------------------
## Step 3: Iterate and PATCH pageSettings (with conditional modifications)
# ---------------------------------------------------------------------
next_action "2. Start Iterative Patch (PATCH modified pageSettings)"
echo "ℹ️  Action: Iterate, apply SEO Title, and conditionally set 'hiddenFromNavigation' inside pageSettings."
echo -e "   ➡️ SEO Title will be: '${SEO_PREFIX}[Page Name]${SEO_SUFFIX}'"
echo -e "ℹ️  Endpoint: ${RED}${BOLD}${PORTAL_URL}${API_PATH}/${TARGET_SITE_ERC}/site-pages/{erc}${RESET} (PATCH)"
wait_for_user

echo "## Starting patching loop..."
echo "---------------------------------------------------------------------"


# Loop through each item in the bash array
for PAGE_ITEM in "${PAGE_INFO_ARRAY[@]}"; do

    # 3a: Data Extraction for this iteration
    PAGE_ERC=$(echo "$PAGE_ITEM" | jq -r '.erc')
    PAGE_NAME=$(echo "$PAGE_ITEM" | jq -r '.name')
    PAGE_SETTINGS_JSON=$(echo "$PAGE_ITEM" | jq -c '.pageSettings')
    PAGE_TYPE=$(echo "$PAGE_ITEM" | jq -r '.pageType') # <-- Contains the actual page type

    # Re-introducing RED BOLD formatting for the page name
    PAGE_DISPLAY_NAME="${RED}${BOLD}${PAGE_NAME}${RESET}"

    # --- 3b: CALCULATE NEW SEO TITLE ---

    # Concatenate the prefix, page name, and suffix to form the new title
    NEW_HTML_TITLE="${SEO_PREFIX}${PAGE_NAME}${SEO_SUFFIX}"

    # --- 3c: MODIFY pageSettings (SEO UPDATE) ---

    # Start modifying pageSettings by adding the SEO HTML Title
    MODIFIED_PAGE_SETTINGS_JSON=$(echo "$PAGE_SETTINGS_JSON" | jq \
        --arg html_title "$NEW_HTML_TITLE" \
        '.seoSettings.htmlTitle_i18n."en-US" = $html_title')

    # --- 3d: CONDITIONAL MODIFICATION: Add hiddenFromNavigation to pageSettings if WidgetPage ---

    REQUEST_METHOD="PATCH"
    TARGET_URL="${PORTAL_URL}${API_PATH}/${TARGET_SITE_ERC}/site-pages/${PAGE_ERC}"

    echo ""
    echo -e "--- Processing Page: ${PAGE_DISPLAY_NAME} (ERC: ${PAGE_ERC}) ---"

    # Check for WidgetPage type and apply 'hiddenFromNavigation: true'
    if [ "${PAGE_TYPE}" = "WidgetPage" ]; then
        echo "   ⚙️ Conditional Modification: MATCH! Nesting 'hiddenFromNavigation: true' inside pageSettings."

        # Use jq to update the MODIFIED_PAGE_SETTINGS_JSON to include hiddenFromNavigation
        MODIFIED_PAGE_SETTINGS_JSON=$(echo "$MODIFIED_PAGE_SETTINGS_JSON" | jq '. + {"hiddenFromNavigation": true}')
    fi

    # --- 3e: Construct the final PATCH payload (Only contains the modified pageSettings object) ---

    # The final payload contains only the pageSettings object, which now has SEO and optionally hiddenFromNavigation
    PATCH_BODY="{\"pageSettings\": $MODIFIED_PAGE_SETTINGS_JSON}"

    echo "   ✅ SEO Modification: Setting 'htmlTitle_i18n.en-US' to: ${NEW_HTML_TITLE}"

    # Display endpoint (bold red)
    echo -e "   ➡️ Sending **${REQUEST_METHOD}** to endpoint: ${RED}${BOLD}${TARGET_URL}${RESET}"
    echo "   ➡️ PATCH Payload (full body):"
    # Displaying the FULL JSON payload for verification
    echo "$PATCH_BODY" | jq '.'

    # Save the payload to a temporary file
    echo "$PATCH_BODY" > "$TEMP_BODY_FILE"

    # --- 3f: Send the PATCH request ---

    PATCH_RESPONSE=$({ set +x; } 2>/dev/null; \
        curl -s -X "${REQUEST_METHOD}" \
        "${TARGET_URL}" \
        -d  @"${TEMP_BODY_FILE}" \
        -H 'Content-Type: application/json' \
        -u "${AUTH}" \
        -w 'SEPARATOR%{http_code}' )

    { set +x; } 2>/dev/null

    RESPONSE_CODE="${PATCH_RESPONSE#*SEPARATOR}"
    RESPONSE_BODY="${PATCH_RESPONSE%SEPARATOR*}"

    if [[ "$RESPONSE_CODE" =~ ^2 ]]; then
        echo -e "   🎉 ${GREEN}SUCCESS${RESET}: Patch applied to ${PAGE_NAME} (HTTP ${RESPONSE_CODE})."
    else
        RESPONSE_BODY="${PATCH_RESPONSE%SEPARATOR*}"
        echo -e "   🚨 ${RED}FAILURE${RESET}: ${REQUEST_METHOD} failed for ${PAGE_NAME} (HTTP ${RESPONSE_CODE})."
        echo "   Response Body (error):"
        echo "$RESPONSE_BODY" | jq '.'
    fi

    # Pause added at the end of each iteration
    next_action "Processing of Page ${PAGE_ERC} completed."
    wait_for_user

done

# --- Cleanup (SILENT EXECUTION) ---
rm -f "$TEMP_BODY_FILE"

echo ""
echo "--- Script Execution Complete ---"

wait_for_user

clear

echo "====================================================================="
echo ""
echo -e "This demonstrates the power of using ${BOLD}PATCH${RESET} requests to perform partial and massive updates on page fields."
echo -e "${BOLD}Automation through the API allows for efficient bulk management of content settings.${RESET}"
echo ""
echo "====================================================================="