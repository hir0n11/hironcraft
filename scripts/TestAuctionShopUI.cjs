const fs = require("fs");

const ui = fs.readFileSync("ProfitHub/Shop/UI/ShoppingList_UI.lua", "utf8");
const sellUi = fs.readFileSync("ProfitHub/Shop/UI/ShoppingList_Selling_UI.lua", "utf8");
const core = fs.readFileSync("ProfitHub/Shop/Core/ShoppingList_Core.lua", "utf8");
const locale = fs.readFileSync("ProfitHub/Shop/Locale.lua", "utf8");
const tabLib = fs.readFileSync("ProfitHub/Core/Libs/LibAHTab/LibAHTab.lua", "utf8");

function check(condition, message) {
  if (!condition) throw new Error(message);
}

check(ui.includes("local CLASSIC_BORDER"), "classic auction border is missing");
check(
  ui.includes("Interface\\\\DialogFrame\\\\UI-DialogBox-Background"),
  "classic Blizzard panel background is missing",
);
check(
  !ui.includes('SetFrameAtlasBackground(frame, "shop-bg-toys"'),
  "legacy toy-shop artwork is still active",
);
check(
  ui.includes('label:SetPoint("CENTER", button, "CENTER", 0, 0)'),
  "button labels are not explicitly centered",
);
check(
  ui.includes("button:SetPushedTextOffset(0, 0)"),
  "pressed buttons still move their text",
);
check(
  locale.includes('PT.L_ruRU["PG_SHOP_TAB"] = "HironCraft"') &&
    !locale.includes('PT.L_ruRU["PG_SHOP_TAB"] = "PH:Shop"'),
  "the Auction House tab still uses the PH:Shop label",
);
check(
  ui.includes("tabLib:MoveTabToFront(AH_TAB_ID)") &&
    tabLib.includes("function lib:MoveTabToFront(tabID)"),
  "the HironCraft tab is not moved before the standard Auction House tabs",
);
check(
  tabLib.includes("local ATTACHED_OFFSET_Y = 20") &&
    tabLib.includes("(anchor[5] or 0) + ATTACHED_OFFSET_Y"),
  "Auction House tabs still leave a vertical gap below the frame",
);
check(
  ui.includes('f.stopScanBtn:SetPoint("TOPRIGHT", f.panel, "TOPRIGHT", -PANEL_PAD, -36)') &&
    ui.includes("f.stopScanBtn:SetShown(scanning)"),
  "the stop-scan control is not isolated in the status row",
);
check(
  ui.includes('btn.label:SetPoint("CENTER", btn, "CENTER", 0, 0)') &&
    ui.includes('btn.value:SetPoint("TOPRIGHT", btn, "TOPRIGHT", -6, -5)') &&
    ui.includes('btn.value:SetSize(26, 7)'),
  "buy actions do not keep the action centered and the hotkey in the corner",
);
check(
  (sellUi.match(/btn\.key = MakeText\(btn, 7, "RIGHT"\)/g) || []).length >= 2 &&
    (sellUi.match(/btn\.key:SetPoint\("TOPRIGHT"[^\n]*-6, -5\)/g) || []).length >= 2 &&
    sellUi.includes('btn.label:SetSize(32, 18)'),
  "selling actions or duration buttons still use unstable native captions",
);
check(
  ui.includes("if AuctionHouseFrame and tabLib and ShouldShowAuctionTab() then"),
  "empty Shop page cannot be opened",
);

const landingSelections = core.match(/S:SetShopTab\("buy"\)/g) || [];
check(
  landingSelections.length >= 2,
  "Shop is not selected from both Auction House open events",
);
check(
  !core.includes('if HasShoppingSession() then\n                        S:ShowWindow()'),
  "Auction House landing still depends on an active shopping session",
);
check(
  core.includes("function CreateTemporaryImportedList(listName, materials, sourceKind, allowEmpty)") &&
    core.includes("if #rows == 0 and not canExpand and not allowEmpty then"),
  "recipe shopping cannot replace its temporary list after all reagents become available",
);

console.log("Auction Shop UI tests passed (classic frame, centered controls, default landing tab).");
