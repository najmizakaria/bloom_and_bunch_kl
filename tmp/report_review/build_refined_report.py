from pathlib import Path
from docx import Document
from docx.enum.section import WD_SECTION
from docx.enum.table import WD_CELL_VERTICAL_ALIGNMENT, WD_TABLE_ALIGNMENT
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.oxml import OxmlElement
from docx.oxml.ns import qn
from docx.shared import Cm, Inches, Pt, RGBColor

OUT = Path('output/documents/Bloom_and_Bunch_KL_Refined_FYP02_Report.docx')
OUT.parent.mkdir(parents=True, exist_ok=True)

doc = Document()
sec = doc.sections[0]
sec.top_margin = Cm(2.5); sec.bottom_margin = Cm(2.5)
sec.left_margin = Cm(3.2); sec.right_margin = Cm(2.5)

styles = doc.styles
styles['Normal'].font.name = 'Arial'; styles['Normal'].font.size = Pt(11)
styles['Normal'].paragraph_format.line_spacing = 1.5
styles['Normal'].paragraph_format.space_after = Pt(6)
for name, size in [('Title', 18), ('Heading 1', 15), ('Heading 2', 13), ('Heading 3', 11)]:
    st = styles[name]
    st.font.name = 'Arial'; st.font.size = Pt(size); st.font.color.rgb = RGBColor(0,0,0)
    st.font.bold = True
    st.paragraph_format.space_before = Pt(12); st.paragraph_format.space_after = Pt(6)
styles['Title'].paragraph_format.space_before = Pt(0)

def set_cell_shading(cell, fill):
    tcPr = cell._tc.get_or_add_tcPr(); shd = OxmlElement('w:shd'); shd.set(qn('w:fill'), fill); tcPr.append(shd)

def set_cell_margins(cell, top=90, start=110, bottom=90, end=110):
    tc = cell._tc; tcPr = tc.get_or_add_tcPr(); tcMar = tcPr.first_child_found_in('w:tcMar')
    if tcMar is None: tcMar = OxmlElement('w:tcMar'); tcPr.append(tcMar)
    for m, v in [('top',top),('start',start),('bottom',bottom),('end',end)]:
        node = tcMar.find(qn('w:'+m))
        if node is None: node=OxmlElement('w:'+m); tcMar.append(node)
        node.set(qn('w:w'), str(v)); node.set(qn('w:type'),'dxa')

def add_table(headers, rows, widths=None):
    table = doc.add_table(rows=1, cols=len(headers)); table.alignment=WD_TABLE_ALIGNMENT.CENTER
    table.style='Table Grid'
    trPr = table.rows[0]._tr.get_or_add_trPr()
    tbl_header = OxmlElement('w:tblHeader')
    tbl_header.set(qn('w:val'), 'true')
    trPr.append(tbl_header)
    for i,h in enumerate(headers):
        c=table.rows[0].cells[i]; set_cell_shading(c,'404040'); c.vertical_alignment=WD_CELL_VERTICAL_ALIGNMENT.CENTER
        p=c.paragraphs[0]; p.alignment=WD_ALIGN_PARAGRAPH.CENTER; r=p.add_run(h); r.bold=True; r.font.color.rgb=RGBColor(255,255,255); r.font.size=Pt(9)
        set_cell_margins(c)
    for ri,row in enumerate(rows):
        cells=table.add_row().cells
        for i,val in enumerate(row):
            c=cells[i]; c.vertical_alignment=WD_CELL_VERTICAL_ALIGNMENT.CENTER; set_cell_margins(c)
            if ri%2: set_cell_shading(c,'F2F2F2')
            p=c.paragraphs[0]; p.alignment=WD_ALIGN_PARAGRAPH.CENTER if len(str(val))<24 else WD_ALIGN_PARAGRAPH.LEFT
            r=p.add_run(str(val)); r.font.size=Pt(9)
    if widths:
        for row in table.rows:
            for i,w in enumerate(widths): row.cells[i].width=Cm(w)
    doc.add_paragraph()
    return table

def add_field(paragraph, instruction):
    run=paragraph.add_run(); begin=OxmlElement('w:fldChar'); begin.set(qn('w:fldCharType'),'begin')
    instr=OxmlElement('w:instrText'); instr.set(qn('xml:space'),'preserve'); instr.text=instruction
    sep=OxmlElement('w:fldChar'); sep.set(qn('w:fldCharType'),'separate')
    text=OxmlElement('w:t'); text.text='Update field in Microsoft Word'
    end=OxmlElement('w:fldChar'); end.set(qn('w:fldCharType'),'end')
    for x in (begin,instr,sep,text,end): run._r.append(x)

def heading(text, level=1):
    p=doc.add_heading(text, level=level); p.paragraph_format.keep_with_next=True; return p

def body(text, bold_lead=None):
    p=doc.add_paragraph(); p.alignment=WD_ALIGN_PARAGRAPH.JUSTIFY
    if bold_lead: r=p.add_run(bold_lead); r.bold=True
    p.add_run(text); return p

def bullets(items):
    for item in items:
        p=doc.add_paragraph(style='List Bullet'); p.paragraph_format.left_indent=Cm(.7); p.add_run(item)

def page_break(): doc.add_page_break()

# Cover
p=doc.add_paragraph(); p.alignment=WD_ALIGN_PARAGRAPH.CENTER; p.paragraph_format.space_before=Pt(90)
r=p.add_run('BLOOM AND BUNCH KUALA LUMPUR'); r.bold=True; r.font.name='Arial'; r.font.size=Pt(20)
p=doc.add_paragraph(); p.style=styles['Title']; p.alignment=WD_ALIGN_PARAGRAPH.CENTER; p.add_run('Mobile Floral Ordering and Delivery Management System')
for text in ['SWE/137/24B','MUHAMMAD NAJMI BIN ZAKARIA\nSAIFUL MIFDHAL BIN SAIFUL MOHZAN\nIRDINA HANNI BINTI AZHAR','Project Supervisor\nMUHAMMAD BAKHTIAR IMAN BIN AWANG','Software Engineering 6\nComputer and Information Department\nGerman Malaysian Institute','September 2026']:
    p=doc.add_paragraph(text); p.alignment=WD_ALIGN_PARAGRAPH.CENTER; p.paragraph_format.space_before=Pt(18)
page_break()

heading('Declaration',1)
body('We declare that this project report describes our own work on the Bloom and Bunch Kuala Lumpur system. Sources used in the study are acknowledged in the reference list. The implementation statements in this revised report have been aligned with the current project repository.')
doc.add_paragraph('\nSignature  Muhammad Najmi Bin Zakaria  ____________________\n\nSignature  Saiful Mifdhal Bin Saiful Mohzan  ____________________\n\nSignature  Irdina Hanni Binti Azhar  ____________________\n\nDate  ____________________')

heading('Acknowledgement',1)
body('We thank our supervisor, Muhammad Bakhtiar Iman bin Awang, the Technical Training Office, our lecturers, classmates, friends, and families for their guidance and support throughout the project. Their feedback helped us improve the system requirements, implementation, testing, and documentation.')

heading('Abstract',1)
body('Bloom and Bunch Kuala Lumpur is a Flutter application for customers, florists, riders, and administrators. The system replaces fragmented ordering through calls and messaging with a structured workflow for browsing products, building custom bouquets, managing carts and saved addresses, placing orders, preparing bouquets, assigning riders, and monitoring delivery status. Firebase Authentication manages access, Cloud Firestore stores application data, Firebase Storage stores product images, and Firebase Cloud Functions enforce server-side order, inventory, rider, and administrative rules. The project achieved the bouquet-customisation objective and substantially achieved the communication objective through structured order records and role-specific workflows. The delivery objective was partially achieved: customers receive real-time order-status updates and rider-assignment information, but the current implementation does not yet display continuously updated rider coordinates, route visualisation, or a customer-selected future delivery date. Static analysis reported no issues and all 18 Flutter tests passed in the September 2026 verification run. Firebase emulator tests documented in the project review also passed, while selected production-device checks remain outstanding.')

heading('Table of Contents',1)
p=doc.add_paragraph(); add_field(p,'TOC \\o "1-3" \\h \\z \\u')
page_break()

heading('Chapter 1 Introduction',1)
heading('1.1 Project Background',2)
body('Bloom and Bunch Kuala Lumpur receives flower orders that may require product selection, bouquet customisation, recipient details, delivery coordination, and communication between customers and shop staff. When these details are spread across phone calls or messaging applications, staff must repeatedly clarify selections, prices, addresses, and delivery progress. The project therefore developed one application that stores the order information and presents the appropriate workflow to each user role.')
body('The current system is a cross-platform Flutter application. It supports customer, florist, rider, and administrator roles. Firebase services provide authentication, data storage, file storage, real-time data streams, push-notification capability, and trusted server-side operations.')

heading('1.2 Problem Statement',2)
heading('1.2.1 Limited bouquet customisation',3)
body('Customers need a clear way to choose flower stems, quantities, wrapping, ribbon, and a gift-card message while seeing the calculated price before adding the bouquet to the cart.')
heading('1.2.2 Fragmented order communication',3)
body('Orders handled through separate calls and messages can omit important information. A structured order record is needed so customers and staff refer to the same items, recipient details, address, notes, price, preparation state, and delivery state.')
heading('1.2.3 Limited delivery visibility and scheduling',3)
body('Customers need clear delivery progress. They also benefit from delivery planning for bouquets that require preparation. The present implementation calculates a preparation timeline and streams order-status changes, but it does not yet provide customer-selected dates or continuous live-map tracking.')

heading('1.3 Project Objectives',2)
add_table(['Objective','Revised measurable statement'],[
('Objective 1','Develop a mobile floral-ordering application that lets customers configure a bouquet and receive a server-validated price.'),
('Objective 2','Improve order clarity between customers and florists by storing complete, structured order and preparation information in one system.'),
('Objective 3','Provide delivery planning and tracking through preparation estimates, rider assignment, and real-time status updates, with live coordinate tracking identified as future work.')], [3.2,12.8])

heading('1.4 Project Scope',2)
body('Customers can register, sign in, browse ready and pre-order bouquets, browse flowers, build custom bouquets, save favourite products and recipes, manage addresses, place orders, review order history, reorder eligible items, and view order progress. Florists can maintain inventory and bouquets, review orders, view required materials, begin preparation, mark orders ready, and cancel eligible orders. Approved riders can view available delivery jobs, accept one delivery, inspect destination details, and mark delivery complete. Administrators can review rider applications and synchronise delivery jobs.')
body('The application targets Android, iOS, web, Windows, macOS, and Linux through Flutter, although the project verification concentrated on Flutter analysis, automated widget tests, Firebase emulator tests, and web builds. The business location recorded in the current application is Unit G2, StreetMall Cyberjaya, Cyberjaya, 63000 Cyberjaya, Selangor.')
heading('1.5 Scope Limitations',2)
bullets(['No live payment gateway is implemented.','The current tracking screen shows order stages and rider assignment, not a continuously moving map or estimated arrival time.','Customers cannot choose an arbitrary future delivery date and time; the server derives a preparation and delivery timeline from fulfillment type and lead time.','Terms of Use and Privacy Policy content remains provisional and requires owner-approved legal text.','Production checks for Google sign-in, device launching of phone and WhatsApp links, and rider approval still require manual validation.'])

heading('Chapter 2 Requirements and Study',1)
heading('2.1 Requirement Collection',2)
body('The original study used stakeholder discussion, a questionnaire, and a comparison with existing online florist services. These activities identified three recurring needs: more control over bouquet composition, clearer order information, and better visibility of delivery progress. The revised requirements were validated against the implemented Flutter screens, Firebase data model, Cloud Functions, security rules, and automated tests.')
heading('2.2 Functional Requirements',2)
add_table(['Area','Implemented requirement'],[
('Account and access','Email/password and Google sign-in, password recovery, profile stream, and role-based routing.'),
('Catalogue','Ready-to-send and pre-order bouquet catalogues, flower catalogue, search/filtering, details, and favourites.'),
('Custom bouquet','Stem selection and limits, wrapping, ribbon, card note, calculated price, saved recipes, and cart integration.'),
('Checkout','Saved recipient addresses, stock- and price-validated server checkout, separate fulfillment groups, and order history.'),
('Florist','Inventory, bouquets, order queue, preparation actions, material summary, and cancellation workflow.'),
('Rider','Application, administrator approval, available jobs, exclusive acceptance, destination details, and delivery completion.'),
('Tracking','Real-time Firestore order-status stream, staged progress, delivery timing text, and rider-assignment state.'),
('Administration','Rider application review and delivery-job synchronisation.')],[3.2,12.8])
heading('2.3 Non Functional Requirements',2)
bullets(['Security: Firestore and Storage rules restrict data by authentication state, ownership, and role. Sensitive price, stock, assignment, and rider-review changes run through Cloud Functions.','Reliability: transactions and idempotent checkout logic reduce duplicate orders and stock races.','Usability: role-specific navigation and responsive Flutter layouts support smaller screens.','Maintainability: domain models, services, feature folders, constants, tests, and lint rules separate responsibilities.','Performance: Firestore streams update affected views without manual refresh, while retained streams reduce unnecessary resubscriptions.'])
heading('2.4 Product Positioning',2)
body('The project differentiates itself through custom stem-level bouquet composition and one workflow shared by customers, florists, riders, and administrators. The original report claimed live location and estimated arrival time. The current product should instead be described as real-time order-status tracking until rider-coordinate publishing, map rendering, routing, and ETA calculation are implemented and tested.')

heading('Chapter 3 Project Methodology and Design',1)
heading('3.1 Development Method',2)
body('The team followed an iterative Agile approach. Requirements were divided into user journeys, implemented in small increments, checked with static analysis and automated tests, and revised after review. The current repository shows successive work on authentication, catalogue behaviour, checkout, order transitions, rider approval, security rules, responsive layout, and release readiness.')
heading('3.2 System Architecture',2)
add_table(['Layer','Technology and responsibility'],[
('Presentation','Flutter and Dart screens, widgets, navigation, theme, forms, and responsive layouts.'),
('Client state','Provider for cart state and Firebase streams for authenticated application data.'),
('Identity','Firebase Authentication for email/password and Google sign-in.'),
('Database','Cloud Firestore for users, addresses, products, favourites, orders, delivery jobs, and rider applications.'),
('Files','Firebase Storage for staff-managed product images.'),
('Trusted backend','Firebase Cloud Functions on Node.js for checkout, stock reservations, order transitions, rider review, and delivery-job synchronisation.'),
('Location support','Geolocator, geocoding, and Google Maps Flutter packages are installed; saved addresses can store coordinates. Live rider tracking is not yet presented in the customer tracking screen.')],[3.2,12.8])
heading('3.3 Data and Role Design',2)
body('The user profile stores role information and supports a customer who is also an approved rider. Orders retain customer identity, immutable item snapshots, totals, recipient and address information, fulfillment type, status, preparation information, rider assignment, and timestamps. Custom-order snapshots preserve stem identifiers and names, wrapping, ribbon, and card notes so florists can prepare the ordered design even if catalogue data later changes.')
heading('3.4 Security Design',2)
body('Firestore rules validate authentication, ownership, allowed roles, permitted fields, coordinate ranges, and staff-only writes. The client cannot directly set trusted totals, reserve stock, assign a rider, or approve a rider application. Cloud Functions repeat role and input validation and use Firestore transactions for consistency.')

heading('Chapter 4 Implementation and Testing',1)
heading('4.1 Customer Implementation',2)
body('The customer application provides authentication, catalogues, details, favourites, custom bouquet design, cart management, saved addresses, checkout, history, reorder, profile management, and order tracking. The custom builder limits invalid quantities, calculates the displayed price from available flower data and selected materials, and submits the selection to a Cloud Function that recalculates the authoritative price.')
heading('4.2 Florist Rider and Administrator Implementation',2)
body('Florists can maintain product information and inventory, review item and material details, move an order into preparation, mark it ready for delivery, or cancel it under the permitted conditions. Approved riders can accept an available job; the backend prevents two riders from accepting the same delivery. Administrators can approve or reject rider applications, and approved users receive rider access without losing the customer role.')
heading('4.3 Delivery Implementation',2)
body('The system divides checkout items by fulfillment needs. Ready items use immediate rider availability, while custom and pre-order items receive a business-day preparation estimate. The customer tracking screen listens to the order document and displays the current stage from confirmation through preparation, rider collection, out-for-delivery, and delivery. This is live status tracking. Continuous GPS coordinates, a rendered route, and an ETA are not part of the current customer screen.')
heading('4.4 Testing Method',2)
body('Testing uses Flutter analysis and Flutter widget tests for application behaviour. Firebase emulator tests cover Cloud Function domain logic, transactions, Firestore rules, and Storage rules. The report no longer claims Selenium, MySQL Workbench, Espresso, or Postman as completed test tools because they are not represented in the current repository evidence.')
add_table(['Verification','Result','Evidence scope'],[
('Flutter static analysis','Passed with no issues','Dart source, lint, and type analysis run on 11 September 2026.'),
('Flutter automated tests','18 passed','Authentication navigation, product components, and widget behaviour.'),
('Firebase emulator suite','18 passed in recorded project review','Checkout races, reservations, cancellation, assignment, rider review, Firestore rules, and Storage rules.'),
('Release web build','Passed in recorded project review','Standard web compilation and WebAssembly dry-run compilation.'),
('Production device checks','Pending','Google account/device authentication, phone and WhatsApp launch, and fresh rider approval flow.')],[4,3,9])

heading('Chapter 5 Results and Objective Evaluation',1)
heading('5.1 Implemented Result',2)
body('The current project is an operational multi-role Flutter and Firebase codebase rather than the React and MySQL mock-up described in the older report. The application contains customer, florist, rider, and administrator workflows, a trusted server checkout, role-based security rules, automated tests, and web-release configuration.')
heading('5.2 Objective Achievement',2)
add_table(['Objective','Assessment','Evidence','Remaining gap'],[
('1 Custom floral ordering','Met','Customers select flowers and quantities, wrapping, ribbon, and a card note; the UI calculates a price and the server validates it before creating the order.','The screen does not assemble a photorealistic bouquet preview or provide a separate colour selector beyond available flower products.'),
('2 Better customer florist clarity','Substantially met','Structured checkout stores item snapshots, recipient details, address, notes, totals, timing, and status. Florists view orders and required materials in role-specific screens.','There is no in-app two-way chat or approval conversation for exceptional requests.'),
('3 Flexible scheduling and tracking','Partially met','The system separates ready and planned fulfillment, calculates business-day preparation timing, assigns riders, and streams order-status changes.','Customers cannot select a future date/time, and the tracking screen has no live rider coordinates, route, or ETA.')],[2.8,2.5,6.2,5.5])
heading('5.3 Discussion',2)
body('Objective 1 has direct UI, domain, backend, and test evidence. Objective 2 is supported because the order becomes a shared, structured record and the florist receives the materials and delivery details needed to fulfil it. This improves clarity even without chat. Objective 3 should not be reported as fully achieved. Firestore provides real-time status updates, but real-time data transport is not the same as real-time GPS tracking. The wording in the abstract, scope, results, and conclusion has therefore been corrected to distinguish the implemented status tracker from the proposed map tracker.')

heading('Chapter 6 Conclusion and Future Work',1)
heading('6.1 Conclusion',2)
body('Bloom and Bunch Kuala Lumpur demonstrates a secure, multi-role floral ordering workflow built with Flutter and Firebase. The project meets the main customisation objective and substantially improves order clarity through consistent digital records and role-specific actions. It also provides useful delivery planning and real-time order-status visibility. However, the evidence does not support a claim that flexible date selection, continuous rider-location tracking, route visualisation, or ETA calculation is complete. The project objective statement and evaluation should retain this distinction until those features are implemented and validated.')
heading('6.2 Recommended Future Work',2)
bullets(['Add a customer date and time-slot selector with florist capacity rules, cutoff times, public-holiday handling, and server validation.','Publish assigned-rider coordinates with explicit consent, background-location controls, update throttling, access rules, and retention limits.','Render the rider route and ETA in the customer tracking screen and test degraded GPS and network conditions.','Integrate a payment provider only after defining payment states, webhook verification, refunds, cancellations, and reconciliation.','Replace provisional Terms of Use and Privacy Policy text with owner-approved content and complete production-device acceptance testing.'])

heading('Appendix A Current Project Evidence Map',1)
add_table(['Repository area','Purpose'],[
('lib features customer','Customer catalogues, custom builder, cart, checkout, addresses, favourites, history, profile, and tracking.'),
('lib features florist','Inventory, bouquets, order lists, order details, preparation, and material summaries.'),
('lib features rider','Application, available jobs, active delivery, destination details, and completion.'),
('lib features admin','Rider application review and delivery-job synchronisation.'),
('lib core services and models','Authentication, Firestore access, order calls, addresses, favourites, location helpers, cart state, and domain models.'),
('functions index.js and domain.js','Trusted checkout, pricing, stock, order transitions, rider approval, and validation.'),
('firestore.rules and storage.rules','Role, ownership, field, path, and file-type enforcement.'),
('test and functions test','Flutter tests and Firebase emulator tests.')],[5,11])

heading('Appendix B Corrections to the Previous Report',1)
add_table(['Previous statement','Corrected statement'],[
('Frontend uses React','The client is built with Flutter and Dart.'),
('Backend uses Node.js and Express.js','Trusted backend operations use Firebase Cloud Functions on Node.js; no standalone Express application is evidenced.'),
('Data is stored in MySQL','Application data is stored in Cloud Firestore and images in Firebase Storage.'),
('Selenium, Espresso, MySQL Workbench, and Postman were used','Repository evidence supports Flutter tests, Flutter analysis, Firebase emulator tests, and web builds.'),
('Live Google Maps tracking and ETA were implemented','The current screen provides real-time order-status tracking and rider-assignment information; live coordinates, route, and ETA remain future work.'),
('Customers select same-day or a future date','Ready and planned fulfillment are supported, but the server calculates the timeline and the customer does not select an arbitrary date/time.'),
('System has two access levels','The current system has customer, florist, rider, and administrator workflows.')],[6.5,9.5])

# Footer with page field
for section in doc.sections:
    fp=section.footer.paragraphs[0]; fp.alignment=WD_ALIGN_PARAGRAPH.CENTER
    fp.add_run('Bloom and Bunch Kuala Lumpur   |   '); add_field(fp,'PAGE')

props=doc.core_properties
props.title='Bloom and Bunch Kuala Lumpur Mobile Floral Ordering and Delivery Management System'
props.subject='Refined Final Year Project Report aligned with the current Flutter and Firebase implementation'
props.author='Muhammad Najmi Bin Zakaria, Saiful Mifdhal Bin Saiful Mohzan, Irdina Hanni Binti Azhar'
doc.save(OUT)
print(OUT.resolve())
