# Site Audit — scSAID header

## Stack and styling layer

- Server-rendered Java/JSP application.
- Shared header markup: `src/main/webapp/includes/header.jsp`.
- Shared header behavior: `src/main/webapp/JS/site-header.js`.
- Shared header styling: `src/main/webapp/CSS/header.css`.
- Global tokens: `src/main/webapp/CSS/design-system.css`.

## Current design tokens and patterns

- Nunito is already the shared interface family.
- Primary blue: `#337ab7`; dark blue: `#23527c`.
- Neutral text: `#333333`, `#555555`, `#777777`.
- Border: `#dddddd` / `#cccccc`.
- Existing dropdowns use 12px radius and a broad `0 12px 24px` shadow.
- Existing desktop search width is 17rem.

## Header structure

- scSAID logo.
- Home, Browse, Search, Expression, Compare, Download, Help, and Feedback navigation.
- Help is the only existing navigation dropdown.
- Site-function/dataset search and a responsive navigation drawer.

## Protected brand equity

- The scSAID name and logo text.
- The established blue accent.
- Existing page content, scientific terminology, routes, and search functionality.

## Functionality to preserve

- Active-page indication.
- Hover, focus, keyboard, and mobile navigation access.
- Existing Help topics.
- Site search autocomplete and direct navigation.
- Search, Compare, Feedback, Browse, Expression, Download, and Home routes.

## Authorized structural changes

- Group Search and Compare under a new Navigate menu.
- Add an About menu with blank How to Cite and What's New destinations.
- Shorten the desktop/tablet search field by approximately 30%.

## Constraints

- Fixed header with desktop-to-drawer breakpoint at 1179px.
- Cloudflare caches versioned CSS/JS assets, so header asset URLs must be bumped.
- Browser automation is unavailable in this session; QA must combine static inspection, build checks, production HTML, and endpoint checks.
