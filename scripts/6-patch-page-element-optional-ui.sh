#!/bin/bash

# =======================================================================
# SCRIPT TO PATCH A SPECIFIC PAGE ELEMENT
# This script directly applies a PATCH to a Page Element's definition
# to change the underlying content (Journal Article ERC).
# Gives the user the option to execute automatically or show UI details.
# =======================================================================

# ANSI Color Codes
RED=$'\033[31m'
RESET=$'\033[0m'
GREEN=$'\033[32m'
BOLD=$'\033[1m'
YELLOW=$'\033[33m'

# -----------------------------------------------------------------------
# --- CONFIGURATION VARIABLES ---
# Reusing ERCs from the previous steps to maintain context (DRAFT version).
# NOTE: These ERCs must be correct for a successful PATCH.
# -----------------------------------------------------------------------

TARGET_SITE_ERC="TargetSite"
# Page Specification ERC (from the newly created DRAFT)
TARGET_PAGE_SPEC_ERC="a1a9e63b-f2f7-e2d0-f4db-9715cc222cba"
# Default page experience ERC
TARGET_PAGE_EXPERIENCE_ERC="ee34d066-70b9-eedf-5f60-551dd766565f"
# The ERC of the specific element (the Fragment) added in the previous step
TARGET_ELEMENT_ERC="MyFragmentPageElement"

TEMP_BODY_FILE="page_element_patch_body.json"
AUTH='test@liferay.com:test'
API_PATH="/o/headless-admin-site/v1.0/sites"
PORTAL_URL="${PORTAL_URL:-http://localhost:8080}"

# --- CONTENT HINTS ---
SITE_CONTENT_ERCS="THE-ART-OF-PINTXOS, TORREZNOS, ZAMBURIñAS-A-LA-GALLEGA"
GLOBAL_CONTENT_ERCS="ACEITUNAS, THE-ICONIC-MADRID-CALAMARI-ROLL, TORTILLA-DE-PATATAS"
GLOBAL_SCOPE_JSON='{
    "scope": {
        "externalReferenceCode": "L_GLOBAL",
        "type" : "Site"
    }
}'


# --- PAYLOADS ---

# PATCH Payload: Updates the fragment definition to point to a new article.
# We are changing the 'externalReferenceCode' from "THE-ART-OF-PINTXOS" to "ZAMBURIñAS-A-LA-GALLEGA".
PATCH_PAYLOAD='{
    "pageElementDefinition": {
        "configuration": "{\"fieldSets\":[{\"label\":\"Content Display Options\",\"fields\":[{\"name\":\"itemSelector\",\"typeOptions\":{\"enableSelectTemplate\":true},\"label\":\"item\",\"type\":\"itemSelector\"}]}]}",
        "css": "",
        "fragmentConfigurationFieldValues": {
           "itemSelector": {
              "type": "Item",
              "value": {
                 "item": {
                    "className": "com.liferay.journal.model.JournalArticle",
                    "externalReferenceCode": "ZAMBURIñAS-A-LA-GALLEGA"
                 },
                 "template": {
                    "rendererKey": "com.liferay.journal.web.internal.info.item.renderer.JournalArticleDDMTemplateInfoItemTemplatedRenderer",
                    "templateKey": "36344"
                 }
              }
           }
        },
        "fragmentReference": {
           "fragmentReferenceType": "DefaultFragmentReference",
           "defaultFragmentKey": "com.liferay.fragment.internal.renderer.ContentObjectFragmentRenderer"
        },
        "fragmentType": "Basic",
        "html": "",
        "indexed": true,
        "js": "",
        "type": "Fragment"
    }
}'

# --- Helper Functions for Step-by-Step Execution ---

# Pauses the script and waits for the user to press ENTER.
wait_for_user() {
    read -rp "" # Waits for ENTER
}

# Displays the next action header
next_action() {
    echo ""
    echo "--- ${BOLD}NEXT Action:${RESET} $1 ---"
    echo ""
}


# Prints CSV list vertically (one item per line)
# $1: CSV string of ERCs
print_ercs_vertically() {
    local ERCS="$1"
    # Use tr to replace commas with newlines, and loop over the lines using IFS to trim spaces
    echo "$ERCS" | tr ',' '\n' | while IFS= read -r erc; do
        erc_trimmed=$(echo "$erc" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        [ -n "$erc_trimmed" ] && echo -e "  - ${GREEN}$erc_trimmed${RESET}"
    done
}


clear # Clear screen

# Construct the base URL for the element
BASE_URL="${PORTAL_URL}${API_PATH}/${TARGET_SITE_ERC}/page-specifications/${TARGET_PAGE_SPEC_ERC}/page-experiences/${TARGET_PAGE_EXPERIENCE_ERC}/page-elements/${TARGET_ELEMENT_ERC}"
PATCH_URL="${BASE_URL}" # Define the PATCH URL here

# --- Initialization Summary ---

echo "====================================================================="
echo "  [PAGE ELEMENT PATCH SCRIPT]"
echo "====================================================================="
echo ""
echo -e "This time, we will use the **Page Element** endpoints since we only want to modify the content of a single element."
echo ""
echo -e "Because we are targeting an element added in the previous step, we are going to invoke the ${BOLD}PATCH${RESET} endpoint directly to update its ${BOLD}pageElementDefinition${RESET}, which contains the necessary content mapping for a Content Display Fragment."
echo ""
echo -e "➡️ Invoking ${BOLD}PATCH${RESET} to endpoint: ${RED}${PATCH_URL}${RESET}"
echo ""

wait_for_user

# --- MODIFIED: User Choice Prompt ---
echo "====================================================================="
echo -e "--- ${BOLD}EXECUTION METHOD${RESET} ---"
echo -e "Press ${BOLD}ENTER${RESET} to run the PATCH automatically."
echo -e "Press ${BOLD}any other key${RESET} to show UI details (Manual Invocation)."
echo "====================================================================="
read -rsn1 CHOICE # Capture a single keypress silently
echo "" # Ensure a newline after silent read

# Check if the captured keypress was ENTER (ASCII 10)
if [ -z "$CHOICE" ]; then
    # CHOICE is empty/null, meaning ENTER was pressed (ASCII 10, or just an empty line)
    CHOICE="1"
else
    # Any other key was pressed
    CHOICE="2"
fi

# ---------------------------------------------------------------------
## Step 1: Handle User Choice
# ---------------------------------------------------------------------

if [[ "$CHOICE" == "1" ]]; then
    # --- OPTION 1: AUTOMATIC INVOCATION (Existing PATCH Logic) ---

    next_action "1. Execute PATCH request to update the Page Element's definition"

    echo "ℹ️  Action: PATCHing Page Element (${TARGET_ELEMENT_ERC}) with new Fragment content (from 'Pintxos' to 'Zamburiñas')."
    echo -e "ℹ️  Endpoint: ${RED}${BOLD}${PATCH_URL}${RESET} (PATCH)"
    echo "   ➡️ New article ERC: ZAMBURIñAS-A-LA-GALLEGA"
    echo ""

    echo "   ➡️ ${BOLD}PATCH Payload Body (pageElementDefinition):${RESET}"
    echo "$PATCH_PAYLOAD" | jq '.'
    echo ""

    # Save the patch payload to a temporary file
    echo "$PATCH_PAYLOAD" > "$TEMP_BODY_FILE"

    wait_for_user

    # Send the PATCH request
    PATCH_RESPONSE=$({ set +x; } 2>/dev/null; \
        curl -s -X 'PATCH' \
        "${PATCH_URL}" \
        -d  @"${TEMP_BODY_FILE}" \
        -H 'Content-Type: application/json' \
        -u "${AUTH}" \
        -w 'SEPARATOR%{http_code}' )

    RESPONSE_CODE="${PATCH_RESPONSE#*SEPARATOR}"
    RESPONSE_BODY="${PATCH_RESPONSE%SEPARATOR*}"

    if [[ "$RESPONSE_CODE" =~ ^2 ]]; then
        echo -e "   🎉 ${GREEN}SUCCESS${RESET}: Page Element updated successfully (HTTP ${RESPONSE_CODE})."
        echo "   📄 Updated Content Reference (Verification):"
        echo "$RESPONSE_BODY" | jq '.pageElementDefinition.fragmentConfigurationFieldValues.itemSelector.value.item.externalReferenceCode'
    else
        echo -e "   🚨 ${RED}FAILURE${RESET}: PATCH request failed (HTTP ${RESPONSE_CODE})."
        echo "   Response Body (error):"
        echo "$RESPONSE_BODY" | jq '.'
        rm -f "$TEMP_BODY_FILE"
        exit 1
    fi

    # Cleanup for option 1
    rm -f "$TEMP_BODY_FILE"

    echo ""
    echo "--- Script Execution Complete ---"

elif [[ "$CHOICE" == "2" ]]; then
    # --- OPTION 2: SHOW UI DETAILS (Skip Invocation) ---
    echo -e "ℹ️  You selected the ${BOLD}Use UI${RESET} option. Skipping endpoint invocation."
    echo ""
    echo "--- ${BOLD}REQUIRED DATA FOR MANUAL INVOCATION${RESET} ---"
    echo ""
    echo -e "${YELLOW}ENDPOINT NAME:${RESET} patchSitePageSpecificationPageExperiencePageElement"
    echo -e "${YELLOW}ENDPOINT PATH:${RESET} /v1.0/sites/{siteExternalReferenceCode}/page-specifications/{pageSpecificationExternalReferenceCode}/page-experiences/{pageExperienceExternalReferenceCode}/page-elements/{pageElementExternalReferenceCode}"
    echo ""
    echo -e "--- ${BOLD}PARAMETERS${RESET} ---"
    echo -e "${YELLOW}siteExternalReferenceCode:${RESET} ${TARGET_SITE_ERC}"
    echo -e "${YELLOW}pageSpecificationExternalReferenceCode:${RESET} ${TARGET_PAGE_SPEC_ERC}"
    echo -e "${YELLOW}pageExperienceExternalReferenceCode:${RESET} ${TARGET_PAGE_EXPERIENCE_ERC}"
    echo -e "${YELLOW}pageElementExternalReferenceCode:${RESET} ${TARGET_ELEMENT_ERC}"
    echo ""
    echo ""
    echo -e "${YELLOW}PAYLOAD (Request Body):${RESET}"
    echo "$PATCH_PAYLOAD" | jq '.'
    echo ""
    echo -e "ℹ️  ${BOLD}Authentication:${RESET} Basic Auth with ${BOLD}${AUTH}${RESET}"
    echo ""


   wait_for_user

    echo -e "\n--- ${BOLD}CONTENT MAPPING HINTS (MODIFYING PAYLOAD) ${RESET}---"
    echo "The content reference is modified by updating the 'externalReferenceCode' inside the 'item' object."
    echo ""


    echo -e "${YELLOW}Available Site Content ERCs:${RESET}"
    print_ercs_vertically "${SITE_CONTENT_ERCS}"
    echo ""

    echo -e "${YELLOW}Available Global Content ERCs:${RESET}"
    print_ercs_vertically "${GLOBAL_CONTENT_ERCS}"
    echo ""

    echo -e "${YELLOW}Scope is required for Global Content mapping:${RESET}"
    echo "You must add the 'scope' property to the 'item' object."
    echo "$GLOBAL_SCOPE_JSON" | jq '.'
    echo "--------------------------------------------------------"
else
    echo -e "🚨 ${RED}Invalid option${RESET}. Terminating script."
    exit 1
fi

wait_for_user

clear

# --- Final Conclusion Text 1 ---
echo "====================================================================="
echo ""
echo -e "This illustrates how the API enables highly ${BOLD}specific and partial modifications${RESET} to a page's content structure."
echo ""
echo "====================================================================="

wait_for_user

clear

# --- Final Conclusion Text 2 ---
echo "====================================================================="
echo ""
echo -e "In conclusion, this demonstration covered the functionality of the ${BOLD}Site Pages${RESET}, ${BOLD}Page Specifications${RESET}, and ${BOLD}Page Elements${RESET} endpoints. We want to emphasize that the actions shown here are also available for other schemas (masters, page templates, display pages templates, and utility pages)."
echo -e "We encourage you to explore the entire ${BOLD}Headless Admin Site API${RESET} where you will find these and many other endpoints being developed in upcoming iterations."
echo ""
echo "====================================================================="