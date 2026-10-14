// 12.1.5 removed a set of deprecated global functions (Blizzard_DeprecatedItemScript
// and others; see warcraft.wiki.gg Patch_12.1.5/API_changes). The tests stand in
// for the game and often define those globals, so a call that the client no
// longer knows passes every other test and fails only in play: the item-link
// banners went quiet that way. Every reference to one of these names must be
// to a local of the file, or the fallback in "C_X and C_X.Y or Name".
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
function loadParser() {
    const places = ['../../test-tools/luaparse-node_modules/luaparse', 'C:/Tools/lua51/node_modules/luaparse', 'luaparse'];
    for (const place of places) {
        try {
            return require(place);
        } catch (error) {
            if (error.code !== 'MODULE_NOT_FOUND') throw error;
        }
    }
    throw new Error('luaparse is not installed: npm install luaparse --prefix C:/Tools/lua51');
}
const lua = loadParser();
const root = path.resolve(process.argv[2] || path.join(__dirname, '..'));
const excluded = new Set(['.git', '.build', 'dist', 'artwork', 'scripts']);

const REMOVED = new Set(`
GetCoinIcon GetCoinText GetCoinTextureString IsOnGlueScreen
GetItemQualityColor GetItemInfoInstant GetItemSetInfo GetItemChildInfo DoesItemContainSpec GetItemGem
GetItemCreationContext GetItemIcon GetItemFamily GetItemSpell IsArtifactPowerItem IsCurrentItem IsUsableItem
IsHelpfulItem IsHarmfulItem IsConsumableItem IsEquippableItem IsEquippedItem IsEquippedItemType ItemHasRange
IsItemInRange GetItemClassInfo GetItemInventorySlotInfo BindEnchant ActionBindsItem ReplaceEnchant
ReplaceTradeEnchant ConfirmBindOnUse ConfirmOnUse ConfirmNoRefundOnUse DropItemOnUnit EndBoundTradeable EndRefund
GetItemInfo GetDetailedItemLevelInfo GetItemSpecInfo GetItemUniqueness GetItemCount PickupItem
GetItemSubClassInfo UseItemByName EquipItemByName ReplaceTradeskillEnchant GetItemCooldown IsCorruptedItem
IsCosmeticItem IsDressableItem
CloseSocketInfo GetSocketItemInfo GetNumSockets GetExistingSocketInfo GetExistingSocketLink GetNewSocketInfo
GetNewSocketLink ClickSocketButton AcceptSockets GetSocketTypes GetSocketItemRefundable
GetSocketItemBoundTradeable HasBoundGemProposed
PetAssistMode GetPetTalentTree IsSubZonePVPPOI GetZonePVPInfo TogglePVP SetPVP PlayVocalErrorSoundID
PickupTradeMoney
`.split(/\s+/).filter(Boolean));

// "C_Item and C_Item.GetItemInfo or GetItemInfo": the namespace is asked
// first, the old name only where it is missing.
function IsFallback(node, parent) {
    if (!parent || parent.type !== 'LogicalExpression' || parent.operator !== 'or' || parent.right !== node) return false;
    const left = parent.left;
    return left && left.type === 'LogicalExpression' && left.operator === 'and'
        && left.right && left.right.type === 'MemberExpression'
        && left.right.base && left.right.base.type === 'Identifier' && /^C_/.test(left.right.base.name);
}

const problems = [];
let parsed = 0, standIns = 0;
// Names a file defines itself as a global of its environment (ShoppingList_Core
// has its own GetItemIcon): those references are to that, not to the game.
function OwnGlobals(node, names) {
    if (!node || typeof node !== 'object') return names;
    if (node.type === 'FunctionDeclaration' && node.identifier && node.identifier.type === 'Identifier'
        && !node.isLocal) names.add(node.identifier.name);
    if (node.type === 'AssignmentStatement') {
        for (const target of node.variables) if (target.type === 'Identifier' && !target.isLocal) names.add(target.name);
    }
    for (const [key, value] of Object.entries(node)) {
        if (key === 'loc' || key === 'range' || key === 'globals' || key === 'comments') continue;
        if (Array.isArray(value)) value.forEach(child => OwnGlobals(child, names));
        else if (value && typeof value === 'object' && value.type) OwnGlobals(value, names);
    }
    return names;
}
function walk(node, parent, file, own) {
    if (!node || typeof node !== 'object') return;
    if (node.type === 'Identifier' && REMOVED.has(node.name) && !node.isLocal && !own.has(node.name)) {
        if (IsFallback(node, parent)) {
            standIns++;
        } else {
            problems.push(`${file}:${node.loc.start.line}: ${node.name}`);
        }
    }
    for (const [key, value] of Object.entries(node)) {
        if (key === 'loc' || key === 'range' || key === 'globals' || key === 'comments') continue;
        // C_Item.GetItemInfo and { GetItemInfo = ... } name a field, not the global.
        if (node.type === 'MemberExpression' && key === 'identifier') continue;
        if (node.type === 'TableKeyString' && key === 'key') continue;
        if (Array.isArray(value)) value.forEach(child => walk(child, node, file, own));
        else if (value && typeof value === 'object' && value.type) walk(value, node, file, own);
    }
}
function walkFiles(dir) {
    for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
        if (excluded.has(entry.name)) continue;
        const full = path.join(dir, entry.name);
        if (entry.isDirectory()) walkFiles(full);
        else if (entry.name.endsWith('.lua')) {
            const file = path.relative(root, full).replaceAll('\\', '/');
            const ast = lua.parse(fs.readFileSync(full, 'utf8'), { luaVersion: '5.1', scope: true, locations: true });
            walk(ast, null, file, OwnGlobals(ast, new Set()));
            parsed++;
        }
    }
}
walkFiles(root);

assert(parsed > 100, 'too few Lua files were read: ' + parsed);
assert(standIns > 0, 'no C_ fallback was recognised: the check itself is broken');
assert.deepEqual(problems, [], 'globals removed in 12.1.5 are still called:\n' + problems.join('\n'));
console.log(`Removed-globals check passed: ${parsed} Lua files, ${standIns} fallbacks after a C_ namespace.`);
