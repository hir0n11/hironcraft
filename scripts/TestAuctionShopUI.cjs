const fs = require("fs");

const ui = fs.readFileSync("ProfitHub/Shop/UI/ShoppingList_UI.lua", "utf8");
const core = fs.readFileSync("ProfitHub/Shop/Core/ShoppingList_Core.lua", "utf8");

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

console.log("Auction Shop UI tests passed (classic frame, centered controls, default landing tab).");
