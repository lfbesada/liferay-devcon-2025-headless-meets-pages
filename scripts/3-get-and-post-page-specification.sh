#!/bin/bash

# =======================================================================
# SCRIPT TO GET, MODIFY, AND POST A PAGE SPECIFICATION DRAFT
# This script retrieves the DRAFT specification, modifies its type, status,
# and a specific page element's properties, and posts a new version. The script
# does NOT delete the new draft afterward.
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
# Page ERC provided by the user
TARGET_PAGE_ERC="0d11c04d-4721-386b-2dd9-346293e4b9e4"

TEMP_BODY_FILE="page_spec_patch_body.json"
AUTH='test@liferay.com:test'
API_PATH="/o/headless-admin-site/v1.0/sites"
# Uses environment variable $PORTAL_URL or default value http://localhost:8080
PORTAL_URL="${PORTAL_URL:-http://localhost:8080}"

# Variable to store the ERC of the newly created specification
NEW_SPEC_ERC=""

# --- MODIFICATION CONFIGURATION ---
PAGE_SPEC_TYPE="ContentPageSpecification"
LIFECYCLE_STATUS_DRAFT="Draft" # Status value as a string

# External Reference Code of the Page Element to modify (the parent receiving the new child)
TARGET_ELEMENT_ERC="0d60e750-4989-1c4b-e8aa-fb58d2464d73"
NEW_MODULES_PER_ROW=4
NEW_NUMBER_OF_MODULES=4
NEW_SIBLING_SIZE=3 # New size property for existing children (siblings), set to 3

# JSON for the new child element to inject into TARGET_ELEMENT_ERC
NEW_CHILD_ELEMENT_JSON='{
    "externalReferenceCode": "MyModulePageElement",
    "pageElementDefinition": {
       "type": "Module",
       "size": 3
    },
    "pageElements": [
       {
          "externalReferenceCode": "MyFragmentPageElement",
          "pageElementDefinition": {
             "type": "Fragment",
             "configuration": "{\"fieldSets\":[{\"label\":\"Content Display Options\",\"fields\":[{\"name\":\"itemSelector\",\"typeOptions\":{\"enableSelectTemplate\":true},\"label\":\"item\",\"type\":\"itemSelector\"}]}]}",
             "css": "",
             "fragmentConfigurationFieldValues": {
                "itemSelector": {
                   "type": "Item",
                   "value": {
                      "item": {
                         "className": "com.liferay.journal.model.JournalArticle",
                         "externalReferenceCode": "THE-ART-OF-PINTXOS"
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
             "js": ""
          },
          "pageElements": [],
          "parentExternalReferenceCode": "MyModulePageElement",
          "position": 0
       }
    ],
    "parentExternalReferenceCode": "0d60e750-4989-1c4b-e8aa-fb58d2464d73",
    "position": 0
}'

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

# --- Initialization Summary (New Intro Text) ---

echo "====================================================================="
echo "  [CREATE PAGE DRAFT WITH CONTENT]"
echo "====================================================================="
echo ""
echo -e "We are going to create a ${BOLD}Draft${RESET} version of the Home Page, adding a new ${BOLD}Card${RESET} containing \"Pintxos\" content to the main banner."
echo -e "Since we only want to modify the content of the draft page, we will use the **Page Specifications** endpoints."
echo ""

# 1. GET Step Description
echo -e "ℹ️  Step 1: ${BOLD}Retrieve Draft Page Specification${RESET}"
echo -e "    We perform a **GET** request for the target page's specification to use as a base for our modifications."
echo -e "    ➡️ ${BOLD}Endpoint:${RESET} ${RED}${BOLD}${PORTAL_URL}${API_PATH}/${TARGET_SITE_ERC}/site-pages/${TARGET_PAGE_ERC}/page-specifications${RESET} (GET)"
echo ""

# 2. Manipulate Step Description
echo -e "ℹ️  Step 2: ${BOLD}Manipulate the Draft Page Specification${RESET}"
echo -e "   - Manipulate the JSON to set the status to ${BOLD}Draft${RESET} and update the target ${BOLD}Grid${RESET} element's configuration."
echo -e "   - Inject a new child element containing the \"Pintxos\" **Content Display Fragment**."
echo ""

# 3. POST Step Description
echo -e "ℹ️  Step 3: ${BOLD}POST  the Draft Page Specification${RESET}"
echo -e "   - **POST** the modified specification to create the new draft version."
echo -e "    ➡️ ${BOLD}Endpoint:${RESET} ${RED}${BOLD}${PORTAL_URL}${API_PATH}/${TARGET_SITE_ERC}/site-pages/${TARGET_PAGE_ERC}/page-specifications${RESET} (POST)"
echo ""

wait_for_user

# ---------------------------------------------------------------------
## Step 1: GET All Page Specifications
# ---------------------------------------------------------------------
GET_URL="${PORTAL_URL}${API_PATH}/${TARGET_SITE_ERC}/site-pages/${TARGET_PAGE_ERC}/page-specifications"

next_action "1. GET Page Specifications"
echo "ℹ️  Action: Retrieve all Page Specifications for the target page to find the base (non-draft) version."
echo -e "ℹ️  Endpoint: ${RED}${BOLD}${GET_URL}${RESET}"
wait_for_user

# Capture JSON response
PAGE_SPECS_JSON=$( { set +x; } 2>/dev/null; \
    curl -s -X 'GET' \
    "${GET_URL}" \
    -u "${AUTH}" )

# Check for successful retrieval
if ! echo "$PAGE_SPECS_JSON" | jq -e '.items' > /dev/null; then
    echo "❌ ERROR: Could not retrieve Page Specifications list or the JSON response is invalid."
    exit 1
fi

TOTAL_SPECS=$(echo "$PAGE_SPECS_JSON" | jq '.totalCount')
echo "✅ EXECUTION COMPLETE: Successfully retrieved ${TOTAL_SPECS} page specification(s)."

# ---------------------------------------------------------------------
## Step 2: Find the DRAFT specification (base for modification)
# ---------------------------------------------------------------------
next_action "2. Prepare POST Payload"
echo "ℹ️  Action: Identifying the Base Page Specification (the one that DOES NOT reference a draft)."

# Use jq -c to filter for the item where draftContentPageSpecificationExternalReferenceCode IS null
BASE_SPEC_JSON=$(echo "$PAGE_SPECS_JSON" | jq -c '.items[] | select(.draftContentPageSpecificationExternalReferenceCode | not)')

if [ -z "$BASE_SPEC_JSON" ]; then
    echo "❌ ERROR: Could not find the base (non-draft) Page Specification. Exiting."
    exit 1
fi


BASE_SPEC_ERC=$(echo "$BASE_SPEC_JSON" | jq -r '.externalReferenceCode')
echo "✅ Found Draft Page Specification (ERC: ${BASE_SPEC_ERC})."
echo "ℹ️  This specification will be used as the base for the new DRAFT version."

# ---------------------------------------------------------------------
## Step 3: Modify the payload: Add type, status, and modify page elements
# ---------------------------------------------------------------------
echo "ℹ️  Action: Modifying 'pageExperiences[0].pageElements' for ERC: ${TARGET_ELEMENT_ERC}:"
echo "   - Setting 'modulesPerRow' and 'numberOfModules' in parent 'pageElementDefinition'."
echo "   - Adding a new child element to the 'pageElements' array (PINTXOS card)."
# Display the new element details
echo "   ➡️ New Child Element JSON (PINTXOS card details to be injected):"
echo "$NEW_CHILD_ELEMENT_JSON" | jq '.'
echo ""
# 3a: Remove debug fields and set common properties (type, status)
MODIFIED_SPEC_PAYLOAD=$(echo "$BASE_SPEC_JSON" | jq \
    --arg spec_type "$PAGE_SPEC_TYPE" \
    --arg spec_status "$LIFECYCLE_STATUS_DRAFT" \
    'del(.id, .externalReferenceCode, .modifiedDate, .draftContentPageSpecificationExternalReferenceCode) |
     .type = $spec_type |
     .status = $spec_status')

# 3b: Search for the specific element by ERC and update its properties
MODIFIED_SPEC_PAYLOAD=$(echo "$MODIFIED_SPEC_PAYLOAD" | jq \
    --arg target_erc "$TARGET_ELEMENT_ERC" \
    --argjson modules_per_row "$NEW_MODULES_PER_ROW" \
    --argjson num_modules "$NEW_NUMBER_OF_MODULES" \
    --argjson new_child_element "$NEW_CHILD_ELEMENT_JSON" \
    --argjson new_sibling_size "$NEW_SIBLING_SIZE" \
    '.pageExperiences[0].pageElements |= map(
        if .externalReferenceCode == $target_erc then
            .pageElementDefinition.modulesPerRow = $modules_per_row |
            .pageElementDefinition.numberOfModules = $num_modules |
            .pageElements |= map(
                # Apply size modification to all existing elements in this array (siblings)
                .pageElementDefinition.size = $new_sibling_size
            ) | .pageElements += [$new_child_element]
        else
            .
        end
    )')

# The final payload for the POST request
POST_PAYLOAD="${MODIFIED_SPEC_PAYLOAD}"


wait_for_user
# ---------------------------------------------------------------------
## Step 4: POST the Modified Page Specification
# ---------------------------------------------------------------------

POST_URL="${PORTAL_URL}${API_PATH}/${TARGET_SITE_ERC}/site-pages/${TARGET_PAGE_ERC}/page-specifications"

next_action "3. POST the Draft Page Specification"
echo "ℹ️  Action: Sending POST request to create a new specification version (DRAFT)."
echo -e "   ➡️ Endpoint: ${RED}${BOLD}${POST_URL}${RESET} (POST)"
        echo "$RESPONSE_BODY" | jq '.'

wait_for_user

# Save the payload to a temporary file
echo "$POST_PAYLOAD" > "$TEMP_BODY_FILE"

# Send the POST request
POST_RESPONSE=$({ set +x; } 2>/dev/null; \
    curl -s -X 'POST' \
    "${POST_URL}" \
    -d  @"${TEMP_BODY_FILE}" \
    -H 'Content-Type: application/json' \
    -u "${AUTH}" \
    -w 'SEPARATOR%{http_code}' )

{ set +x; } 2>/dev/null

RESPONSE_CODE="${POST_RESPONSE#*SEPARATOR}"
RESPONSE_BODY="${POST_RESPONSE%SEPARATOR*}"

if [[ "$RESPONSE_CODE" =~ ^2 ]]; then
    NEW_SPEC_ERC=$(echo "$RESPONSE_BODY" | jq -r '.externalReferenceCode')

    echo -e "   🎉 ${GREEN}SUCCESS${RESET}: New DRAFT version of Page Specification created (HTTP ${RESPONSE_CODE})."
    echo "   New Specification ERC: ${NEW_SPEC_ERC} (Status: DRAFT)"

else
    echo -e "   🚨 ${RED}FAILURE${RESET}: POST request failed (HTTP ${RESPONSE_CODE})."
    echo "   Response Body (error):"
    echo "$RESPONSE_BODY" | jq '.'
    # Exit script on failed POST
    rm -f "$TEMP_BODY_FILE"
    exit 1
fi

# --- Cleanup (SILENT EXECUTION) ---
rm -f "$TEMP_BODY_FILE"

echo ""
echo "--- Script Execution Complete ---"

wait_for_user

clear

# --- Final Conclusion Text ---
echo "====================================================================="
echo ""
echo -e "This demonstrates how a single ${BOLD}POST request can achieve complex updates—creating a draft and modifying its content${RESET} layout—which would typically involve multiple steps within the user interface."
echo ""
echo "====================================================================="