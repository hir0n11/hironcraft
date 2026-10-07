// Static regression checks complement the mocked event/click tests.
// They enforce this addon's chosen manual-action policy, not Blizzard approval.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
// The Lua parser is not part of the addon. It is looked for where this test
// was first written and next to the other test tools:
//   npm install luaparse --prefix C:/Tools/lua51
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
const calls = [], functions = new Map();
let parsed = 0;

function name(node) {
    if (!node) return '';
    if (node.type === 'Identifier') return node.name;
    if (node.type === 'MemberExpression') return name(node.base) + '.' + name(node.identifier);
    return '';
}
function walkAST(node, file) {
    if (!node || typeof node !== 'object') return;
    if (node.type === 'CallExpression') calls.push({ node, name: name(node.base), file });
    if (node.type === 'FunctionDeclaration' && node.identifier) {
        functions.set(file + ':' + name(node.identifier), node);
    }
    for (const value of Object.values(node)) {
        if (Array.isArray(value)) value.forEach(child => walkAST(child, file));
        else if (value && typeof value === 'object') walkAST(value, file);
    }
}
function walkFiles(dir) {
    for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
        if (excluded.has(entry.name)) continue;
        const full = path.join(dir, entry.name);
        if (entry.isDirectory()) walkFiles(full);
        else if (entry.name.endsWith('.lua')) {
            const file = path.relative(root, full).replaceAll('\\', '/');
            const ast = lua.parse(fs.readFileSync(full, 'utf8'), { luaVersion: '5.1' });
            walkAST(ast, file);
            parsed++;
        }
    }
}
walkFiles(root);

assert(!fs.existsSync(path.join(root, 'Libs/RobotsDotTxtClient.lua')), 'legacy whisper listener still ships');
const manualFiles = [
    'HironCraft.toc', 'Consts.lua', 'Settings/Settings.lua', 'Utils/Utils.lua',
    'Customer/ChatScanner.lua', 'Customer/OrderPage.lua', 'Customer/OrderPage.xml',
];
for (const file of manualFiles) {
    assert(!/RobotsDotTxt|auto_replies_enabled|AUTO_REPLIES_SUPPORTED|AutoReplyButton|auto_reply_delay/.test(
        fs.readFileSync(path.join(root, file), 'utf8')), 'retired auto-reply path: ' + file);
}

const ownCalls = calls.filter(call => !call.file.startsWith('Libs/'));
// Also through pcall: the central sender catches the game's refusal of a
// message that is too long ("Chat message limits exceeded").
const directChat = ownCalls.filter(call => /(^|\.)SendChatMessage$/.test(call.name)
    || (call.name === 'pcall' && /(^|\.)SendChatMessage$/.test(name(call.node.arguments[0]))));
assert.deepEqual(directChat.map(call => call.file), ['Utils/Utils.lua'], 'player chat bypassed the central sender');
const bnetSends = ownCalls.filter(call => /(^|\.)(BNSendWhisper|SendWhisper)$/.test(call.name)
    || (call.name === 'pcall' && /(^|\.)(BNSendWhisper|SendWhisper)$/.test(name(call.node.arguments[0]))));
assert.deepEqual(bnetSends.map(call => call.file), ['Utils/Utils.lua', 'Utils/Utils.lua'],
    'Battle.net chat bypassed the guarded central sender');

function checkManualCalls(method, files, flagIndex = -1) {
    const matched = ownCalls.filter(call => call.name.endsWith('.' + method));
    assert.deepEqual(matched.map(call => call.file).sort(), files.sort(), 'review new ' + method + ' callers');
    for (const call of matched) {
        const flag = call.node.arguments.at(flagIndex);
        assert(flag && flag.type === 'BooleanLiteral' && flag.value === true,
            'missing manual-action opt-in: ' + call.file + ':' + call.name);
    }
}
// QuickReplies twice: a reply card (SendOption) and the reason of a decline
// sent again (SendDeclineReason, 0.4.114), which runs on a click of its card
// or of its line in the chat menu.
checkManualCalls('SendResponses', [
    'Customer/CustomExplanations.lua', 'Customer/OrderGreetings.lua',
    'Customer/QuickReplies.lua', 'Customer/QuickReplies.lua', 'Utils/Comm.lua',
]);
checkManualCalls('SendOrderGreeting', [
    'Customer/OrderPage.lua', 'Customer/QuickReplies.lua',
], 1); // The optional third argument identifies the greeting's source.
checkManualCalls('RequestCraft', ['Customer/CustomerPage.lua']);
checkManualCalls('ConfirmSellPost', ['ProfitHub/Shop/Core/ShoppingList_Selling.lua']);

function checkGuard(key) {
    const fn = functions.get(key);
    assert(fn, 'missing guarded function: ' + key);
    const clause = fn.body[0]?.clauses?.[0];
    assert(clause && clause.condition.type === 'BinaryExpression'
        && clause.condition.operator === '~='
        && name(clause.condition.left) === 'userInitiated'
        && clause.condition.right.type === 'BooleanLiteral'
        && clause.condition.right.value === true
        && clause.body[0].type === 'ReturnStatement'
        && clause.body[0].arguments[0].value === false, 'missing early manual-action guard: ' + key);
}
checkGuard('Utils/Utils.lua:HironCraftScan.Utils.SendResponses');
checkGuard('Customer/OrderGreetings.lua:Scan.SendOrderGreeting');
checkGuard('Utils/Comm.lua:HironCraftScanComm.RequestCraft');
checkGuard('ProfitHub/Shop/Core/ShoppingList_Selling.lua:S.ConfirmSellPost');
const retired = functions.get('ProfitHub/Shop/Core/ShoppingList_Core.lua:S.AdvanceBuyAll');
assert(retired && retired.body.length === 1
    && name(retired.body[0].expression?.base) === 'self.StopBuyAll', 'buy-all execution was reintroduced');
console.log(`Manual policy checks passed; ${parsed} addon Lua files parsed as Lua 5.1.`);
