import fs from "node:fs/promises";
import { SpreadsheetFile, Workbook } from "@oai/artifact-tool";

const outputDir = "outputs/01a08ac6-0ea3-78a0-aadc-eb5b41bd6e90";
const previewDir = "tmp/gantt_build/previews";
await fs.mkdir(outputDir, { recursive: true });
await fs.mkdir(previewDir, { recursive: true });

const workbook = Workbook.create();
const improved = workbook.worksheets.add("Improved Gantt");
const source = workbook.worksheets.add("Source Schedule");

const fontFamily = "Arial";
const navy = "#1F4E78";
const blue = "#2F75B5";
const paleBlue = "#D9EAF7";
const grid = "#D9E1F2";
const text = "#1F2937";
const phases = {
  "Planning & Requirements": "#F8CBAD",
  "Research & Documentation": "#FFE699",
  "System & UX Design": "#BDD7EE",
  "Technical Foundation": "#C6E0B4",
  "Core Development": "#A9D18E",
  "Testing & Quality": "#FFF2CC",
  "Deployment & Handover": "#F4B183",
  "Review & Presentation": "#D9E1F2",
  "Project Management": "#D9D9D9",
};

const improvedTasks = [
  ["Planning & Requirements", "FYP briefing and team responsibilities", 1, 1, "Team roles confirmed"],
  ["Planning & Requirements", "Define problem statement, objectives and scope", 1, 2, "Approved project scope"],
  ["Planning & Requirements", "Stakeholder interviews and user questionnaire", 2, 3, "User needs summary"],
  ["Planning & Requirements", "Functional and non-functional requirements", 3, 4, "Requirements specification"],
  ["Planning & Requirements", "Proposal review and supervisor approval", 4, 4, "Proposal approved"],
  ["Research & Documentation", "Literature review and comparable-system study", 2, 6, "Literature review"],
  ["Research & Documentation", "Methodology and FYP 1 report drafting", 6, 10, "Draft FYP 1 report"],
  ["System & UX Design", "Use cases and user journeys", 4, 5, "Use-case model"],
  ["System & UX Design", "System architecture and application flow", 5, 6, "Architecture and flowcharts"],
  ["System & UX Design", "Database model and Firebase security design", 5, 7, "ERD and security model"],
  ["System & UX Design", "Customer, florist, rider and admin UI/UX", 6, 8, "Reviewed interface prototype"],
  ["System & UX Design", "Sequence, activity and class diagrams", 7, 8, "Complete UML design"],
  ["Technical Foundation", "Flutter project structure and Firebase configuration", 9, 10, "Configured development environment"],
  ["Technical Foundation", "Authentication, user roles and profile management", 10, 12, "Working role-based access"],
  ["Technical Foundation", "Core Firestore models, indexes and storage", 11, 13, "Validated data layer"],
  ["Testing & Quality", "FYP 1 prototype testing and corrections", 12, 13, "Stable FYP 1 prototype"],
  ["Review & Presentation", "FYP 1 progress presentation", 10, 10, "Progress presentation"],
  ["Review & Presentation", "FYP 1 submission and demonstration", 14, 14, "FYP 1 submitted"],
  ["Core Development", "Customer catalogue, favourites, cart and bouquet builder", 15, 17, "Customer shopping flow"],
  ["Core Development", "Checkout, address, order history and tracking", 17, 19, "Complete customer order flow"],
  ["Core Development", "Florist product, inventory and order management", 16, 19, "Florist operations module"],
  ["Core Development", "Rider application, delivery jobs and live location", 18, 21, "Rider delivery module"],
  ["Core Development", "Admin dashboard and user/order oversight", 20, 22, "Admin management module"],
  ["Core Development", "Notifications, Cloud Functions and security rules", 21, 23, "Integrated backend services"],
  ["Core Development", "End-to-end integration and code refactoring", 22, 23, "Integrated release candidate"],
  ["Testing & Quality", "Unit and widget testing", 20, 23, "Automated test results"],
  ["Testing & Quality", "Integration testing and user acceptance testing", 23, 25, "UAT findings and sign-off"],
  ["Testing & Quality", "Bug fixes, performance and security review", 24, 26, "Resolved priority defects"],
  ["Deployment & Handover", "Production Firebase configuration and data checks", 25, 26, "Production environment ready"],
  ["Deployment & Handover", "Release build, backup and user guide", 26, 27, "Release package and guide"],
  ["Review & Presentation", "Final report and presentation preparation", 25, 27, "Final report and presentation"],
  ["Review & Presentation", "Internal presentation", 25, 25, "Internal assessment"],
  ["Review & Presentation", "External presentation and final submission", 28, 28, "Final assessment"],
  ["Project Management", "Weekly supervisor review, GitHub update and risk tracking", 1, 27, "Weekly progress evidence"],
];

function columnName(n) {
  let s = "";
  while (n > 0) {
    n--;
    s = String.fromCharCode(65 + (n % 26)) + s;
    n = Math.floor(n / 26);
  }
  return s;
}

function styleBase(sheet, lastRow) {
  sheet.showGridLines = false;
  const used = sheet.getRange(`A1:AI${lastRow}`);
  used.format.font = { name: fontFamily, size: 10, color: text };
  used.format.verticalAlignment = "center";
  sheet.getRange("A:A").format.columnWidth = 25;
  sheet.getRange("B:B").format.columnWidth = 46;
  sheet.getRange("C:E").format.columnWidth = 10;
  sheet.getRange("F:F").format.columnWidth = 30;
  sheet.getRange("G:G").format.columnWidth = 14;
  for (let c = 8; c <= 35; c++) sheet.getRange(`${columnName(c)}:${columnName(c)}`).format.columnWidth = 4.2;
}

// Improved plan
const improvedLast = 5 + improvedTasks.length;
styleBase(improved, improvedLast + 8);
improved.tabColor = navy;
improved.mergeCells("A1:AI1");
improved.getRange("A1").values = [["BLOOM & BUNCH KL - FINAL YEAR PROJECT GANTT CHART"]];
improved.getRange("A1:AI1").format = {
  font: { name: fontFamily, size: 16, bold: true, color: "#FFFFFF" },
  fill: navy,
  horizontalAlignment: "center",
  verticalAlignment: "center",
};
improved.getRange("A1:AI1").format.rowHeight = 30;
improved.mergeCells("A2:AI2");
improved.getRange("A2").values = [["28-week implementation plan | FYP 1: Weeks 1-14 | FYP 2: Weeks 15-28"]];
improved.getRange("A2:AI2").format = {
  font: { name: fontFamily, size: 10, italic: true, color: "#4B5563" },
  horizontalAlignment: "left",
};
improved.getRange("A3:AI3").format.rowHeight = 8;

improved.mergeCells("A4:G4");
improved.getRange("A4").values = [["Task breakdown"]];
improved.mergeCells("H4:U4");
improved.getRange("H4").values = [["FYP 1 (Weeks 1-14)"]];
improved.mergeCells("V4:AI4");
improved.getRange("V4").values = [["FYP 2 (Weeks 15-28)"]];
improved.getRange("A4:AI4").format = {
  fill: blue,
  font: { name: fontFamily, size: 11, bold: true, color: "#FFFFFF" },
  horizontalAlignment: "center",
  verticalAlignment: "center",
};
const headers = ["Phase", "Task", "Start\nWeek", "End\nWeek", "Duration\n(Weeks)", "Deliverable", "Status", ...Array.from({ length: 28 }, (_, i) => i + 1)];
improved.getRange("A5:AI5").values = [headers];
improved.getRange("A5:AI5").format = {
  fill: blue,
  font: { name: fontFamily, size: 10, bold: true, color: "#FFFFFF" },
  horizontalAlignment: "center",
  verticalAlignment: "center",
  wrapText: true,
  borders: { preset: "all", style: "thin", color: "#FFFFFF" },
};
improved.getRange("A5:AI5").format.rowHeight = 34;

const taskValues = improvedTasks.map(([phase, task, start, end, deliverable]) => [phase, task, start, end, null, deliverable, "Not Started"]);
improved.getRange(`A6:G${improvedLast}`).values = taskValues;
improved.getRange("E6").formulas = [["=D6-C6+1"]];
improved.getRange(`E6:E${improvedLast}`).fillDown();
improved.getRange(`A6:G${improvedLast}`).format.borders = {
  insideHorizontal: { style: "thin", color: grid },
  bottom: { style: "thin", color: grid },
};
improved.getRange(`A6:B${improvedLast}`).format.horizontalAlignment = "left";
improved.getRange(`C6:E${improvedLast}`).format.horizontalAlignment = "center";
improved.getRange(`F6:F${improvedLast}`).format.wrapText = true;
improved.getRange(`G6:G${improvedLast}`).format.horizontalAlignment = "center";
improved.getRange(`G6:G${improvedLast}`).dataValidation = { rule: { type: "list", values: ["Not Started", "In Progress", "Completed", "Blocked"] } };
improved.getRange(`H6:AI${improvedLast}`).format = {
  fill: "#FFFFFF",
  borders: { preset: "all", style: "thin", color: grid },
};
improved.getRange(`A6:AI${improvedLast}`).format.rowHeight = 25;

for (const [phase, color] of Object.entries(phases)) {
  improved.getRange(`H6:AI${improvedLast}`).conditionalFormats.addCustom(
    `=AND(H$5>=$C6,H$5<=$D6,$A6="${phase}")`,
    { fill: color, border: { top: { style: "thin", color: color }, bottom: { style: "thin", color: color } } },
  );
  improved.getRange(`A6:A${improvedLast}`).conditionalFormats.addCustom(`=$A6="${phase}"`, { fill: color, font: { bold: true, color: "#1F2937" } });
}
improved.getRange(`G6:G${improvedLast}`).conditionalFormats.add("containsText", { text: "Completed", format: { fill: "#C6E0B4", font: { bold: true, color: "#375623" } } });
improved.getRange(`G6:G${improvedLast}`).conditionalFormats.add("containsText", { text: "In Progress", format: { fill: "#FFF2CC", font: { bold: true, color: "#7F6000" } } });
improved.getRange(`G6:G${improvedLast}`).conditionalFormats.add("containsText", { text: "Blocked", format: { fill: "#F4CCCC", font: { bold: true, color: "#9C0006" } } });

const legendRow = improvedLast + 2;
improved.getRange(`A${legendRow}`).values = [["Legend"]];
improved.getRange(`A${legendRow}`).format.font = { name: fontFamily, size: 10, bold: true, color: text };
const legendSlots = [
  ["B", "C"], ["D", "E"], ["F", "G"],
  ["B", "C"], ["D", "E"], ["F", "G"],
  ["B", "C"], ["D", "E"], ["F", "G"],
];
Object.entries(phases).forEach(([phase, color], index) => {
  const legendLine = legendRow + Math.floor(index / 3);
  const [startCol, endCol] = legendSlots[index];
  improved.mergeCells(`${startCol}${legendLine}:${endCol}${legendLine}`);
  improved.getRange(`${startCol}${legendLine}`).values = [[phase]];
  improved.getRange(`${startCol}${legendLine}:${endCol}${legendLine}`).format = { fill: color, font: { name: fontFamily, size: 9, color: text }, horizontalAlignment: "center", borders: { preset: "outside", style: "thin", color: "#B7B7B7" } };
});
const noteRow = legendRow + 4;
improved.mergeCells(`A${noteRow}:AI${noteRow}`);
improved.getRange(`A${noteRow}`).values = [["Schedule improvements: added project documentation, module-specific development, continuous testing, Firebase/security work, deployment preparation, weekly supervision and risk tracking."]];
improved.getRange(`A${noteRow}:AI${noteRow}`).format = { fill: paleBlue, font: { name: fontFamily, size: 10, italic: true, color: text }, wrapText: true };
improved.getRange(`A${noteRow}:AI${noteRow}`).format.rowHeight = 30;
improved.freezePanes.freezeRows(5);
improved.freezePanes.freezeColumns(7);

// Faithful transcription of the attached PDF schedule.
const sourceTasks = [
  ["Requirement Phase", "Choose team member", 1, 1],
  ["Requirement Phase", "FYP Briefing", 1, 1],
  ["Requirement Phase", "Brainstorming Idea", 1, 2],
  ["Requirement Phase", "Propose idea to supervisor", 2, 2],
  ["Requirement Phase", "Choose project to proceed", 3, 3],
  ["Requirement Phase", "Research secondary sources", 3, 4],
  ["Requirement Phase", "Questionnaire", 4, 4],
  ["Design Phase", "Design Use Case", 5, 5],
  ["Design Phase", "Design Flowchart", 5, 6],
  ["Design Phase", "Design Sequence Diagram", 6, 7],
  ["Design Phase", "Design Activity Diagram", 7, 7],
  ["Design Phase", "Design Class Diagram", 7, 8],
  ["Design Phase", "Design Project Apps UI/UX", 8, 9],
  ["Development Phase", "Database", 11, 15],
  ["Development Phase", "User Registration", 11, 12],
  ["Development Phase", "User Login", 12, 13],
  ["Development Phase", "User Logout", 13, 13],
  ["Development Phase", "Server", 14, 16],
  ["Development Phase", "View Inventory", 16, 18],
  ["Development Phase", "Dashboard", 18, 20],
  ["Testing Phase", "Validation and Verification", 20, 22],
  ["Deployment Phase", "Test online server", 22, 23],
  ["Deployment Phase", "Domain installation", 23, 24],
  ["Deployment Phase", "GitHub update", 24, 25],
  ["Review / Presentation Phase", "Progress Presentation", 10, 10],
  ["Review / Presentation Phase", "Internal Presentation", 25, 25],
  ["Review / Presentation Phase", "External Presentation", 28, 28],
];
const sourceLast = 5 + sourceTasks.length;
styleBase(source, sourceLast + 5);
source.getRange("F:F").format.columnWidth = 3;
source.getRange("G:G").format.columnWidth = 3;
source.tabColor = "#9EADBA";
source.mergeCells("A1:AI1");
source.getRange("A1").values = [["SOURCE SCHEDULE FROM ATTACHED PDF"]];
source.getRange("A1:AI1").format = { fill: navy, font: { name: fontFamily, size: 16, bold: true, color: "#FFFFFF" }, horizontalAlignment: "center" };
source.getRange("A1:AI1").format.rowHeight = 30;
source.mergeCells("A2:AI2");
source.getRange("A2").values = [["Transcribed from FYP_Gantt_Chart.xlsx - FYP Gantt Chart.pdf"]];
source.getRange("A2:AI2").format.font = { name: fontFamily, size: 10, italic: true, color: "#4B5563" };
source.mergeCells("A4:E4");
source.getRange("A4").values = [["Task breakdown"]];
source.mergeCells("H4:U4");
source.getRange("H4").values = [["FYP 1 (Weeks 1-14)"]];
source.mergeCells("V4:AI4");
source.getRange("V4").values = [["FYP 2 (Weeks 15-28)"]];
source.getRange("A4:AI4").format = { fill: blue, font: { name: fontFamily, size: 11, bold: true, color: "#FFFFFF" }, horizontalAlignment: "center" };
source.getRange("A5:AI5").values = [["Phase", "Task", "Start\nWeek", "End\nWeek", "Duration\n(Weeks)", "", "", ...Array.from({ length: 28 }, (_, i) => i + 1)]];
source.getRange("A5:AI5").format = { fill: blue, font: { name: fontFamily, size: 10, bold: true, color: "#FFFFFF" }, horizontalAlignment: "center", wrapText: true, borders: { preset: "all", style: "thin", color: "#FFFFFF" } };
source.getRange("A5:AI5").format.rowHeight = 34;
source.getRange(`A6:D${sourceLast}`).values = sourceTasks;
source.getRange("E6").formulas = [["=D6-C6+1"]];
source.getRange(`E6:E${sourceLast}`).fillDown();
source.getRange(`A6:E${sourceLast}`).format.borders = { insideHorizontal: { style: "thin", color: grid }, bottom: { style: "thin", color: grid } };
source.getRange(`C6:E${sourceLast}`).format.horizontalAlignment = "center";
source.getRange(`H6:AI${sourceLast}`).format = { borders: { preset: "all", style: "thin", color: "#D0D0D0" } };
source.getRange(`A6:AI${sourceLast}`).format.rowHeight = 23;
const sourcePhaseColors = {
  "Requirement Phase": "#FCE4D6",
  "Design Phase": "#D9E2F3",
  "Development Phase": "#E2F0D9",
  "Testing Phase": "#FFF2CC",
  "Deployment Phase": "#FCE4D6",
  "Review / Presentation Phase": "#E4DFEC",
};
for (const [phase, color] of Object.entries(sourcePhaseColors)) {
  source.getRange(`H6:AI${sourceLast}`).conditionalFormats.addCustom(`=AND(H$5>=$C6,H$5<=$D6,$A6="${phase}")`, { fill: color });
  source.getRange(`A6:A${sourceLast}`).conditionalFormats.addCustom(`=$A6="${phase}"`, { fill: color, font: { bold: true, color: text } });
}
source.freezePanes.freezeRows(5);
source.freezePanes.freezeColumns(7);

workbook.recalculate();

const improvedInspect = await workbook.inspect({ kind: "table", range: `Improved Gantt!A1:AI${improvedLast}`, include: "values,formulas", tableMaxRows: 40, tableMaxCols: 12, maxChars: 12000 });
console.log("IMPROVED_INSPECT\n" + improvedInspect.ndjson);
const errors = await workbook.inspect({ kind: "match", searchTerm: "#REF!|#DIV/0!|#VALUE!|#NAME\\?|#N/A|#NUM!|#NULL!|#SPILL!|#CALC!", options: { useRegex: true, maxResults: 100 }, summary: "final formula error scan" });
console.log("ERROR_SCAN\n" + errors.ndjson);

for (const sheetName of ["Improved Gantt", "Source Schedule"]) {
  const preview = await workbook.render({ sheetName, autoCrop: "all", scale: 1, format: "png" });
  await fs.writeFile(`${previewDir}/${sheetName.replaceAll(" ", "_")}.png`, new Uint8Array(await preview.arrayBuffer()));
}

const output = await SpreadsheetFile.exportXlsx(workbook);
await output.save(`${outputDir}/Bloom_and_Bunch_FYP_Gantt_Chart.xlsx`);
console.log(`OUTPUT=${outputDir}/Bloom_and_Bunch_FYP_Gantt_Chart.xlsx`);
