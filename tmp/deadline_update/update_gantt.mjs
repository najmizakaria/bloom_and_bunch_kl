import fs from "node:fs/promises";
import { FileBlob, SpreadsheetFile } from "@oai/artifact-tool";

const inputPath = "../../outputs/01a08ac6-0ea3-78a0-aadc-eb5b41bd6e90/Bloom_and_Bunch_FYP_Gantt_Chart.xlsx";
const outputDir = "../../outputs/01a08ac6-0ea3-78a0-aadc-eb5b41bd6e90";
const outputPath = `${outputDir}/Bloom_and_Bunch_FYP_Gantt_Chart_Deadline_Aligned.xlsx`;
await fs.mkdir(outputDir, { recursive: true });

const workbook = await SpreadsheetFile.importXlsx(await FileBlob.load(inputPath));
const improved = workbook.worksheets.getItem("Improved Gantt");
improved.getRange("A2").values = [["28-week implementation plan | See FYP2 Deadline Plan for the official July-December 2026 calendar"]];

const sheet = workbook.worksheets.add("FYP2 Deadline Plan");
sheet.tabColor = "#C55A11";
sheet.showGridLines = false;

const navy = "#1F4E78";
const blue = "#2F75B5";
const grid = "#D9E1F2";
const text = "#1F2937";
const fontFamily = "Arial";
const colors = {
  "Development": "#A9D18E",
  "Testing & Quality": "#C6E0B4",
  "Documentation": "#FFE699",
  "Official Submission": "#F4B183",
  "Presentation": "#D9E1F2",
  "Ongoing / Administration": "#D9D9D9",
};

const periods = [
  ["TW1", "06-10 Jul"], ["TW2", "13-17 Jul"], ["TW3", "20-24 Jul"], ["TW4", "27-31 Jul"],
  ["TW5", "03-07 Aug"], ["TW6", "10-14 Aug"], ["TW7", "17-21 Aug"], ["TW8", "24-28 Aug"],
  ["TW9", "07-11 Sep"], ["TW10", "14-18 Sep"], ["TW11", "21-25 Sep"], ["TW12", "28 Sep-02 Oct"],
  ["TW13", "05-09 Oct"], ["TW14", "12-16 Oct"], ["TW15", "19-23 Oct"], ["TW16", "26-30 Oct"],
  ["TW17", "02-06 Nov"], ["TW18", "09-13 Nov"], ["RW", "16-20 Nov"], ["EW1", "23-27 Nov"],
  ["EW2", "30 Nov-04 Dec"], ["SB1", "07-11 Dec"], ["SB2", "14-18 Dec"], ["SB3", "21-25 Dec"],
];

// Category, activity, official period, official date, evidence, status, note, start index, end index.
const tasks = [
  ["Official Submission", "Attend FYP2 briefing", "TW1", "10.07.2026", "Briefing attendance", "Not Started", "Official deadline", 1, 1],
  ["Official Submission", "Display Gantt chart, organizational chart and project brief", "TW2", "17.07.2026", "Project-area display", "Not Started", "Official deadline", 2, 2],
  ["Development", "Customer catalogue, favourites, cart and bouquet builder", "TW1-TW4", "", "Customer shopping flow", "Not Started", "Project development plan", 1, 4],
  ["Development", "Florist product, inventory and order management", "TW2-TW6", "", "Florist operations module", "Not Started", "Project development plan", 2, 6],
  ["Development", "Rider application, delivery jobs and live location", "TW4-TW8", "", "Rider delivery module", "Not Started", "Project development plan", 4, 8],
  ["Development", "Admin dashboard and user/order oversight", "TW6-TW9", "", "Admin management module", "Not Started", "Project development plan", 6, 9],
  ["Development", "Cloud Functions, notifications and Firebase security rules", "TW7-TW10", "", "Integrated backend services", "Not Started", "Project development plan", 7, 10],
  ["Development", "End-to-end integration and code refactoring", "TW9-TW12", "", "Integrated release candidate", "Not Started", "Project development plan", 9, 12],
  ["Testing & Quality", "Unit and widget testing", "TW4-TW10", "", "Automated test results", "Not Started", "Continuous testing", 4, 10],
  ["Testing & Quality", "Integration testing and user acceptance testing", "TW10-TW13", "", "UAT findings and sign-off", "Not Started", "Complete before final fixes", 10, 13],
  ["Testing & Quality", "Bug fixes, performance and security review", "TW12-TW15", "", "Resolved priority defects", "Not Started", "Complete before final build", 12, 15],
  ["Development", "Production configuration, release build, backup and user guide", "TW14-TW16", "", "Release package and user guide", "Not Started", "Ready for final presentation", 14, 16],
  ["Official Submission", "Submit purchase requisition", "TW7-TW8", "17-26.08.2026*", "Purchase requisition", "Not Started", "Source prints 17.08-26.08.03.2026; interpreted from the explicit TW7-TW8 period", 7, 8],
  ["Ongoing / Administration", "Submit FYP log book to the supervisor shared folder", "TW1-TW18", "Every Friday", "Weekly log-book entry", "Not Started", "Weekly official requirement", 1, 18],
  ["Ongoing / Administration", "Supervisor review, GitHub update and risk tracking", "TW1-TW18", "Weekly", "Weekly progress evidence", "Not Started", "Project management activity", 1, 18],
  ["Documentation", "Complete and submit FYP documentation Chapters 1-3", "TW1-TW8", "28.08.2026", "Chapters 1-3", "Not Started", "Official deadline", 1, 8],
  ["Presentation", "Progress Presentation 1", "TW10", "14-18.09.2026", "Progress presentation", "Not Started", "Official presentation window", 10, 10],
  ["Documentation", "Complete and submit FYP documentation Chapters 4-6", "TW9-TW12", "02.10.2026", "Chapters 4-6", "Not Started", "Official deadline", 9, 12],
  ["Documentation", "Complete and submit all report chapters", "TW13-TW16", "30.10.2026", "All report chapters", "Not Started", "Official deadline", 13, 16],
  ["Presentation", "Progress Presentation 2", "TW16", "26-30.10.2026", "Progress presentation", "Not Started", "Official presentation window", 16, 16],
  ["Presentation", "Internal presentation", "RW", "16-20.11.2026", "Internal assessment", "Not Started", "Tentative in source", 19, 19],
  ["Ongoing / Administration", "Supervisor submits FYP2 marks to project coordinator", "EW1", "20.11.2026", "Supervisor mark submission", "Not Started", "Source labels EW1; stated date falls in RW", 20, 20],
  ["Presentation", "External presentation", "EW2", "30.11-04.12.2026", "External assessment", "Not Started", "Tentative in source", 21, 21],
  ["Official Submission", "Return store items and submit clearance form", "EX2", "30.11-04.12.2026", "Clearance form", "Not Started", "Source uses EX2; placed in EW2 by date", 21, 21],
  ["Official Submission", "Submit petty-cash claim and budget-control forms if applicable", "EW2-SB1", "30.11-10.12.2026", "Petty-cash forms", "Not Started", "Only if applicable", 21, 22],
  ["Ongoing / Administration", "Project coordinator keys all FYP marks into the system", "SB1", "10.12.2026 (TBC)", "Marks entered", "Not Started", "Administrative deadline", 22, 22],
  ["Documentation", "Submit complete FYP package, consent form, manual, slides and poster", "SB3", "23.12.2026", "Complete FYP submission package", "Not Started", "Upload to the shared folder", 17, 24],
];

function colName(n) {
  let s = "";
  while (n > 0) {
    n--;
    s = String.fromCharCode(65 + (n % 26)) + s;
    n = Math.floor(n / 26);
  }
  return s;
}

const timelineStartCol = 8; // H
const timelineEndCol = timelineStartCol + periods.length - 1;
const timelineEnd = colName(timelineEndCol);
const lastRow = 7 + tasks.length;

sheet.mergeCells(`A1:${timelineEnd}1`);
sheet.getRange("A1").values = [["BLOOM & BUNCH KL - FYP2 DEADLINE PLAN"]];
sheet.getRange(`A1:${timelineEnd}1`).format = {
  fill: navy,
  font: { name: fontFamily, size: 16, bold: true, color: "#FFFFFF" },
  horizontalAlignment: "center",
  verticalAlignment: "center",
};
sheet.getRange(`A1:${timelineEnd}1`).format.rowHeight = 30;

sheet.mergeCells(`A2:${timelineEnd}2`);
sheet.getRange("A2").values = [["Official calendar aligned to the July 2026 academic-session deadline document"]];
sheet.getRange(`A2:${timelineEnd}2`).format = { font: { name: fontFamily, size: 10, italic: true, color: "#4B5563" } };
sheet.mergeCells(`A3:${timelineEnd}3`);
sheet.getRange("A3").values = [["TW9 resumes on 7 September based on the dated milestones. Deadline wording is preserved where the source contains an inconsistency."]];
sheet.getRange(`A3:${timelineEnd}3`).format = { fill: "#FFF2CC", font: { name: fontFamily, size: 9, color: "#7F6000" } };
sheet.getRange(`A4:${timelineEnd}4`).format.rowHeight = 8;

for (const range of ["A5:A7", "B5:B7", "C5:C7", "D5:D7", "E5:E7", "F5:F7", "G5:G7"]) sheet.mergeCells(range);
sheet.getRange("A5:G5").values = [["Category", "Task or deadline", "Official period", "Official date", "Evidence or deliverable", "Status", "Notes"]];
sheet.mergeCells("H5:Y5");
sheet.getRange("H5").values = [["Teaching Weeks"]];
sheet.mergeCells("Z5:AE5");
sheet.getRange("Z5").values = [["Review, Exam and Semester Break Periods"]];
sheet.getRange(`A5:${timelineEnd}5`).format = {
  fill: blue,
  font: { name: fontFamily, size: 10, bold: true, color: "#FFFFFF" },
  horizontalAlignment: "center",
  verticalAlignment: "center",
  borders: { preset: "all", style: "thin", color: "#FFFFFF" },
};
sheet.getRange("H6:AE6").values = [periods.map(p => p[0])];
sheet.getRange("H7:AE7").values = [periods.map(p => p[1])];
sheet.getRange("H6:AE7").format = {
  fill: blue,
  font: { name: fontFamily, size: 8, bold: true, color: "#FFFFFF" },
  horizontalAlignment: "center",
  verticalAlignment: "center",
  wrapText: true,
  borders: { preset: "all", style: "thin", color: "#FFFFFF" },
};
sheet.getRange("A5:G7").format = {
  fill: blue,
  font: { name: fontFamily, size: 10, bold: true, color: "#FFFFFF" },
  horizontalAlignment: "center",
  verticalAlignment: "center",
  wrapText: true,
  borders: { preset: "all", style: "thin", color: "#FFFFFF" },
};
sheet.getRange("H7:AE7").format.rowHeight = 32;

sheet.getRange(`A8:G${lastRow}`).values = tasks.map(t => t.slice(0, 7));
sheet.getRange(`A8:G${lastRow}`).format = {
  font: { name: fontFamily, size: 9, color: text },
  verticalAlignment: "center",
  borders: { insideHorizontal: { style: "thin", color: grid }, bottom: { style: "thin", color: grid } },
};
sheet.getRange(`B8:B${lastRow}`).format.wrapText = true;
sheet.getRange(`C8:F${lastRow}`).format.horizontalAlignment = "center";
sheet.getRange(`E8:E${lastRow}`).format.wrapText = true;
sheet.getRange(`G8:G${lastRow}`).format.wrapText = true;
sheet.getRange(`F8:F${lastRow}`).dataValidation = { rule: { type: "list", values: ["Not Started", "In Progress", "Completed", "Blocked"] } };
sheet.getRange(`H8:${timelineEnd}${lastRow}`).format = {
  fill: "#FFFFFF",
  borders: { preset: "all", style: "thin", color: grid },
};
sheet.getRange(`A8:${timelineEnd}${lastRow}`).format.rowHeight = 30;

tasks.forEach((task, index) => {
  const row = 8 + index;
  const color = colors[task[0]];
  sheet.getRange(`A${row}`).format = { fill: color, font: { name: fontFamily, size: 9, bold: true, color: text } };
  const startCol = timelineStartCol + task[7] - 1;
  const endCol = timelineStartCol + task[8] - 1;
  sheet.getRange(`${colName(startCol)}${row}:${colName(endCol)}${row}`).format.fill = color;
});

sheet.getRange(`F8:F${lastRow}`).conditionalFormats.add("containsText", { text: "Completed", format: { fill: "#C6E0B4", font: { bold: true, color: "#375623" } } });
sheet.getRange(`F8:F${lastRow}`).conditionalFormats.add("containsText", { text: "In Progress", format: { fill: "#FFF2CC", font: { bold: true, color: "#7F6000" } } });
sheet.getRange(`F8:F${lastRow}`).conditionalFormats.add("containsText", { text: "Blocked", format: { fill: "#F4CCCC", font: { bold: true, color: "#9C0006" } } });

sheet.getRange("A:A").format.columnWidth = 24;
sheet.getRange("B:B").format.columnWidth = 50;
sheet.getRange("C:C").format.columnWidth = 15;
sheet.getRange("D:D").format.columnWidth = 20;
sheet.getRange("E:E").format.columnWidth = 31;
sheet.getRange("F:F").format.columnWidth = 14;
sheet.getRange("G:G").format.columnWidth = 34;
for (let c = timelineStartCol; c <= timelineEndCol; c++) sheet.getRange(`${colName(c)}:${colName(c)}`).format.columnWidth = 8.5;

const legendRow = lastRow + 2;
sheet.getRange(`A${legendRow}:C${legendRow}`).values = [["Colour", "Category", "Meaning"]];
sheet.getRange(`A${legendRow}:C${legendRow}`).format = { fill: blue, font: { name: fontFamily, size: 10, bold: true, color: "#FFFFFF" }, horizontalAlignment: "center", borders: { preset: "all", style: "thin", color: "#FFFFFF" } };
const meanings = {
  "Development": "Application feature development and release preparation",
  "Testing & Quality": "Testing, validation, fixes and security review",
  "Documentation": "Report chapters and final submission package",
  "Official Submission": "Official student submission or required action",
  "Presentation": "Progress, internal or external presentation",
  "Ongoing / Administration": "Recurring work or administrative deadline",
};
Object.entries(colors).forEach(([category, color], index) => {
  const row = legendRow + 1 + index;
  sheet.getRange(`A${row}`).values = [[""]];
  sheet.getRange(`A${row}`).format = { fill: color, borders: { preset: "all", style: "thin", color: "#B7B7B7" } };
  sheet.getRange(`B${row}:C${row}`).values = [[category, meanings[category]]];
  sheet.getRange(`B${row}:C${row}`).format = { font: { name: fontFamily, size: 9, color: text }, borders: { preset: "all", style: "thin", color: "#D9D9D9" } };
});
sheet.getRange("A:A").format.columnWidth = 24;
sheet.getRange("B:B").format.columnWidth = 50;
sheet.getRange("C:C").format.columnWidth = 15;

const sourceRow = legendRow + 8;
sheet.mergeCells(`A${sourceRow}:${timelineEnd}${sourceRow}`);
sheet.getRange(`A${sourceRow}`).values = [["Source: FYP2 DEADLINES - JULY 2026 - CID.docx. Schedule activities without an official date are planning recommendations aligned around the stated deadlines."]];
sheet.getRange(`A${sourceRow}:${timelineEnd}${sourceRow}`).format = { fill: "#D9EAF7", font: { name: fontFamily, size: 9, italic: true, color: text }, wrapText: true };
sheet.getRange(`A${sourceRow}:${timelineEnd}${sourceRow}`).format.rowHeight = 28;

sheet.freezePanes.freezeRows(7);
sheet.freezePanes.freezeColumns(7);

workbook.recalculate();
const check = await workbook.inspect({ kind: "table", range: `FYP2 Deadline Plan!A1:${timelineEnd}${lastRow}`, include: "values,formulas", tableMaxRows: 40, tableMaxCols: 10, maxChars: 14000 });
console.log("DEADLINE_PLAN_CHECK\n" + check.ndjson);
const errors = await workbook.inspect({ kind: "match", searchTerm: "#REF!|#DIV/0!|#VALUE!|#NAME\\?|#N/A|#NUM!|#NULL!|#SPILL!|#CALC!", options: { useRegex: true, maxResults: 100 }, summary: "final formula error scan" });
console.log("ERROR_SCAN\n" + errors.ndjson);

const preview = await workbook.render({ sheetName: "FYP2 Deadline Plan", autoCrop: "all", scale: 1, format: "png" });
await fs.writeFile("after.png", new Uint8Array(await preview.arrayBuffer()));
const improvedPreview = await workbook.render({ sheetName: "Improved Gantt", autoCrop: "all", scale: 1, format: "png" });
await fs.writeFile("after_improved.png", new Uint8Array(await improvedPreview.arrayBuffer()));
const output = await SpreadsheetFile.exportXlsx(workbook);
await output.save(outputPath);
console.log(`OUTPUT=${outputPath}`);
