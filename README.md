# 💻 Headless meets Pages: Unleashing the power of Pages REST APIs

This repository contains the scripts demonstrated during the **Liferay DevCon 2025** presentation: **"Headless meets Pages: Unleashing the power of Pages REST APIs."**

The purpose of these scripts is to illustrate how to programmatically interact with Liferay DXP's Pages and Page Fragment architecture using the Pages REST APIs, effectively bridging the gap between traditional DXP sites and modern Headless applications.

This development is currently managed under the Dev Feature Flag LPD-35443. Please be aware that, as this is an active development, the functionality, API, or usage instructions are subject to change.

## 🚀 Presentation Goal

The session focuses on practical use cases, showing **Headless Admin API** site-pages, page-specifications, and page-elements endpoints to **perform full and partial modifications of single and multiple pages**.

## 🛠️ Included Scripts

The following scripts were used to perform the live demonstrations. They are numbered in the recommended execution order.

| Script Name | Description                                                                                                                                                    | Key API Operations                                                                     |
| :--- |:---------------------------------------------------------------------------------------------------------------------------------------------------------------|:---------------------------------------------------------------------------------------|
| **1-migrate-site-pages.sh** | Utility script to perform a full migration or setup of pages across sites. Used for initial environment preparation.                                           | `GET /site-pages`, `POST /site-page`, `PUT /site-page/{sitePageExternalReferenceCode}` |
| **2-get-and-patch-site-pages.sh** | Retrieves the existing page and applies necessary configuration patches.                                                                                       | `GET /site-pages`, `PATCH /site-page/{sitePageExternalReferenceCode}`                  |
| **3-get-and-post-page-specification.sh** | Focuses on creating a draft page specification of a page adding content (fragments, elements, content structure) by retrieving and then posting modifications. | `GET /site-pages/{sitePageExternalReferenceCode}/page-specifications`, `POST /site-pages/{sitePageExternalReferenceCode}/page-specification`                      |
| **4-patch-page-element-optional-ui.sh** | A focused example of modifying specific page elements, such as updating UI configurations or content within a page fragment.                                   | `PATCH /page-element`                                                                  |


## 🔗 Resources

* [Liferay DevCon 2025 Event Page](https://www.liferay.com/web/events/devcon2025/home)
* [Liferay Pages REST API Documentation](hhttps://learn.liferay.com/w/dxp/integration/headless-apis/using-liferay-as-a-headless-platform/consuming-apis/consuming-rest-services)

## 👤 Author

* **Lourdes Fernández Besada** - Staff Software Engineer at Liferay

---
_Feel free to reach out with any questions regarding the implementation or the APIs demonstrated!_