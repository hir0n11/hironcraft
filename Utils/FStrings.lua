local HironCraftScan = select(2, ...)

local function f(s, dict)
    return (s:gsub("{(.-)}", function(key)
        return dict[key] or "{"..key.."}"
    end))
end

HironCraftScan.Utils.FString = f;


-- Conservative misspelling distance, shared by the quick-reply keywords and
-- the equipment aliases so both recognise the same typos. Returns nil when the
-- words are too far apart to be the same word, or too short to guess at.
-- Restricted ASCII words only: a Cyrillic word is one byte sequence away from
-- far too many others.
local function IsAsciiWord(word)
    return type(word) == 'string' and word:match('^[a-z]+$') ~= nil
end

HironCraftScan.Utils.IsAsciiWord = IsAsciiWord

-- Real words a customer writes on purpose. One edit away from a keyword they
-- are still not typos: "help" is not "helm", "stuff" is not "staff", "boost"
-- is not "boots", "danger" is not "dagger".
local COMMON_WORDS = {
    ['about'] = true, ['after'] = true, ['again'] = true, ['also'] = true, ['back'] = true, ['bank'] = true,
    ['bars'] = true, ['base'] = true, ['bash'] = true, ['beat'] = true, ['been'] = true, ['beer'] = true, ['bell'] = true, 
    ['bent'] = true, ['best'] = true, ['bets'] = true, ['bill'] = true, ['bind'] = true, ['bird'] = true, ['bite'] = true, ['blue'] = true,
    ['body'] = true, ['bold'] = true, ['bolt'] = true, ['bone'] = true, ['book'] = true, ['boost'] = true, ['boosts'] = true, 
    ['born'] = true, ['boss'] = true, ['both'] = true, ['bought'] = true, ['bound'] = true, ['bowl'] = true, ['brace'] = true, ['braces'] = true,
    ['bread'] = true, ['break'] = true, ['bring'] = true, ['brings'] = true, ['brought'] = true, ['build'] = true, ['built'] = true, ['burn'] = true,
    ['busy'] = true, ['buys'] = true, ['cake'] = true, ['call'] = true, ['calm'] = true, ['came'] = true, ['camp'] = true, ['cant'] = true,
    ['card'] = true, ['care'] = true, ['case'] = true, ['cast'] = true, ['cats'] = true, ['cause'] = true, ['chase'] = true, ['cheap'] = true,
    ['cheat'] = true, ['check'] = true, ['chess'] = true, ['chip'] = true, ['chips'] = true, ['clean'] = true, ['clear'] = true, ['clock'] = true,
    ['close'] = true, ['code'] = true, ['coin'] = true, ['cold'] = true, ['come'] = true, ['cool'] = true, ['core'] = true,
    ['cost'] = true, ['could'] = true, ['crafted'] = true, ['crafting'] = true, ['crest'] = true, ['crew'] = true, ['cute'] = true, ['dance'] = true,
    ['danger'] = true, ['date'] = true, ['days'] = true, ['dead'] = true, ['deal'] = true, ['dear'] = true, ['deep'] = true, ['does'] = true,
    ['done'] = true, ['door'] = true, ['down'] = true, ['draw'] = true, ['drop'] = true, ['dude'] = true, ['dust'] = true, ['each'] = true,
    ['easy'] = true, ['else'] = true, ['even'] = true, ['ever'] = true, ['face'] = true, ['fact'] = true, ['fail'] = true, ['fair'] = true,
    ['fall'] = true, ['fame'] = true, ['fast'] = true, ['feel'] = true, ['feels'] = true, ['fell'] = true, ['felt'] = true, ['fill'] = true,
    ['find'] = true, ['fine'] = true, ['fire'] = true, ['fish'] = true, ['five'] = true, ['flat'] = true, ['food'] = true, ['fool'] = true,
    ['form'] = true, ['forms'] = true, ['free'] = true, ['from'] = true, ['full'] = true, ['fund'] = true, ['game'] = true, ['gave'] = true,
    ['give'] = true, ['glad'] = true, ['goes'] = true, ['gold'] = true, ['gone'] = true, ['good'] = true, ['gray'] = true, ['great'] = true,
    ['grow'] = true, ['guys'] = true, ['half'] = true, ['hall'] = true, ['hang'] = true, ['hard'] = true,
    ['hate'] = true, ['have'] = true, ['heal'] = true, ['hear'] = true, ['heat'] = true, ['held'] = true,
    ['hell'] = true, ['hello'] = true, ['help'] = true, ['here'] = true, ['hero'] = true, ['hers'] = true, ['high'] = true, ['hill'] = true,
    ['hint'] = true, ['hold'] = true, ['hole'] = true, ['home'] = true, ['hope'] = true, ['host'] = true, ['hour'] = true, ['huge'] = true,
    ['hunt'] = true, ['idea'] = true, ['into'] = true, ['join'] = true, ['joke'] = true, ['just'] = true, ['keep'] = true,
    ['kept'] = true, ['kill'] = true, ['kind'] = true, ['king'] = true, ['kiss'] = true, ['knew'] = true, ['know'] = true, ['lady'] = true,
    ['laid'] = true, ['land'] = true, ['last'] = true, ['late'] = true, ['lead'] = true, ['left'] = true, ['lend'] = true, ['less'] = true,
    ['lets'] = true, ['life'] = true, ['lift'] = true, ['like'] = true, ['line'] = true, ['list'] = true, ['live'] = true, ['load'] = true,
    ['loan'] = true, ['lock'] = true, ['long'] = true, ['look'] = true, ['loot'] = true, ['lord'] = true, ['lose'] = true, ['loss'] = true,
    ['lost'] = true, ['lots'] = true, ['love'] = true, ['loves'] = true, ['made'] = true, ['main'] = true, ['make'] = true,
    ['male'] = true, ['many'] = true, ['mark'] = true, ['mass'] = true, ['mate'] = true, ['math'] = true, ['meal'] = true, ['mean'] = true,
    ['meat'] = true, ['meet'] = true, ['melt'] = true, ['mind'] = true, ['mine'] = true, ['miss'] = true, ['mode'] = true, ['mood'] = true,
    ['moon'] = true, ['more'] = true, ['most'] = true, ['move'] = true, ['much'] = true, ['must'] = true, ['name'] = true, ['near'] = true,
    ['need'] = true, ['never'] = true, ['news'] = true, ['next'] = true, ['nice'] = true, ['nick'] = true, ['nine'] = true, ['none'] = true,
    ['note'] = true, ['older'] = true, ['once'] = true, ['only'] = true, ['open'] = true, ['over'] = true, ['pack'] = true,
    ['page'] = true, ['paid'] = true, ['pain'] = true, ['pair'] = true, ['park'] = true, ['part'] = true, ['pass'] = true, ['past'] = true,
    ['path'] = true, ['pays'] = true, ['pick'] = true, ['pile'] = true, ['plan'] = true, ['play'] = true, ['plays'] = true, ['plus'] = true,
    ['pool'] = true, ['poor'] = true, ['post'] = true, ['pull'] = true, ['pure'] = true, ['push'] = true, ['race'] = true, ['rain'] = true,
    ['rang'] = true, ['rank'] = true, ['rate'] = true, ['read'] = true, ['real'] = true, ['rent'] = true, ['rest'] = true, ['rich'] = true,
    ['ride'] = true, ['rise'] = true, ['risk'] = true, ['road'] = true, ['rock'] = true, ['role'] = true, ['roll'] = true, ['room'] = true,
    ['rule'] = true, ['runs'] = true, ['rush'] = true, ['safe'] = true, ['said'] = true, ['sale'] = true, ['same'] = true, ['sand'] = true,
    ['save'] = true, ['says'] = true, ['seat'] = true, ['seek'] = true, ['seem'] = true, ['seen'] = true, ['self'] = true, ['sell'] = true,
    ['send'] = true, ['sense'] = true, ['sets'] = true, ['shop'] = true, ['show'] = true, ['shut'] = true, ['sick'] = true, ['side'] = true,
    ['sign'] = true, ['sing'] = true, ['size'] = true, ['skin'] = true, ['slow'] = true, ['snow'] = true, ['soft'] = true, ['sold'] = true,
    ['some'] = true, ['song'] = true, ['soon'] = true, ['sort'] = true, ['soul'] = true, ['spare'] = true, ['speed'] = true, ['spend'] = true,
    ['spending'] = true, ['spent'] = true, ['spot'] = true, ['star'] = true, ['stay'] = true, ['step'] = true, ['still'] = true, ['stop'] = true,
    ['stuff'] = true, ['such'] = true, ['sure'] = true, ['take'] = true, ['tale'] = true, ['talk'] = true, ['tall'] = true, ['task'] = true,
    ['team'] = true, ['tell'] = true, ['tend'] = true, ['term'] = true, ['test'] = true, ['text'] = true, ['than'] = true, ['that'] = true,
    ['them'] = true, ['then'] = true, ['they'] = true, ['thin'] = true, ['this'] = true, ['thus'] = true, ['till'] = true, ['time'] = true,
    ['tiny'] = true, ['told'] = true, ['took'] = true, ['tool'] = true, ['town'] = true, ['tree'] = true, ['trip'] = true, ['true'] = true,
    ['turn'] = true, ['type'] = true, ['unit'] = true, ['upon'] = true, ['used'] = true, ['user'] = true, ['uses'] = true, ['very'] = true,
    ['view'] = true, ['wait'] = true, ['wake'] = true, ['walk'] = true, ['wall'] = true, ['want'] = true, ['warm'] = true, ['wash'] = true,
    ['wave'] = true, ['ways'] = true, ['wear'] = true, ['week'] = true, ['well'] = true, ['went'] = true, ['were'] = true, ['what'] = true,
    ['when'] = true, ['whom'] = true, ['wide'] = true, ['wife'] = true, ['wild'] = true, ['will'] = true, ['wind'] = true, ['wine'] = true,
    ['wing'] = true, ['wise'] = true, ['wish'] = true, ['with'] = true, ['word'] = true, ['words'] = true, ['work'] = true, ['world'] = true,
    ['worn'] = true, ['yard'] = true, ['yeah'] = true, ['year'] = true, ['your'] = true, ['zero'] = true,
}

-- The single edit that turns one word into the other, or nil.
local function SingleEdit(typed, target)
    local lt, lg = #typed, #target
    if lt == lg then
        local first, count = nil, 0
        for i = 1, lt do
            if typed:byte(i) ~= target:byte(i) then
                count = count + 1
                first = first or i
                if count > 2 then return nil end
            end
        end
        if count == 1 then return 'substitute' end
        if count == 2 and typed:byte(first) == target:byte(first + 1)
            and typed:byte(first + 1) == target:byte(first) then
            return 'transpose'
        end
        return nil
    end
    if math.abs(lt - lg) ~= 1 then return nil end
    local longer, shorter = typed, target
    if lg > lt then longer, shorter = target, typed end
    local i = 1
    while i <= #shorter and longer:byte(i) == shorter:byte(i) do i = i + 1 end
    if longer:sub(i + 1) ~= shorter:sub(i) then return nil end
    return lt > lg and 'insert' or 'delete'
end

-- Whether a typed word is a misspelling of a keyword, as a distance (1 or 2),
-- or nil. Built on how people actually mistype:
-- * the first letter is almost always right (king/ring, meet/feet are words);
-- * a short word loses, doubles or swaps letters ("staf", "charr", "writs");
--   a changed letter in a short word makes another word (sent/send, crest/
--   chest, help/helm), so that only counts from six letters on;
-- * a real word is never a typo, and long words may take two edits.
function HironCraftScan.Utils.TypoDistance(typed, target, minimumLength)
    if typed == target then return 0 end
    if not IsAsciiWord(typed) or not IsAsciiWord(target) then return nil end
    if COMMON_WORDS[typed] then return nil end
    minimumLength = minimumLength or 4
    if #typed < minimumLength or #target < minimumLength then return nil end
    if typed:byte(1) ~= target:byte(1) then return nil end

    local edit = SingleEdit(typed, target)
    if edit then
        if edit == 'substitute' and #target < 6 then return nil end
        return 1
    end
    if #target >= 10 then
        local distance = HironCraftScan.Utils.FuzzyWordDistance(typed, target, 10)
        if distance == 2 then return 2 end
    end
    return nil
end

HironCraftScan.Utils.IsCommonWord = function(word) return COMMON_WORDS[word] == true end

function HironCraftScan.Utils.FuzzyWordDistance(lhs, rhs, minimumLength)
    if type(lhs) ~= 'string' or type(rhs) ~= 'string' then return nil end
    if lhs == rhs then return 0 end
    if not IsAsciiWord(lhs) or not IsAsciiWord(rhs) then return nil end

    local longest = math.max(#lhs, #rhs)
    if longest < (minimumLength or 6) then return nil end
    -- One typo in a short word, two only once a word is long enough that two
    -- edits still leave it recognisable.
    local limit = longest >= 10 and 2 or 1
    if math.abs(#lhs - #rhs) > limit then return nil end

    local distance = {}
    for i = 0, #lhs do
        distance[i] = { [0] = i }
    end
    for j = 0, #rhs do
        distance[0][j] = j
    end

    for i = 1, #lhs do
        local rowMinimum = limit + 1
        for j = 1, #rhs do
            local cost = lhs:byte(i) == rhs:byte(j) and 0 or 1
            local value = math.min(
                distance[i - 1][j] + 1,
                distance[i][j - 1] + 1,
                distance[i - 1][j - 1] + cost
            )
            -- Swapped neighbours ("writs" for "wrist") are one typo, not two.
            if i > 1 and j > 1
                and lhs:byte(i) == rhs:byte(j - 1)
                and lhs:byte(i - 1) == rhs:byte(j)
            then
                value = math.min(value, distance[i - 2][j - 2] + 1)
            end
            distance[i][j] = value
            rowMinimum = math.min(rowMinimum, value)
        end
        if rowMinimum > limit and i > #rhs + limit then
            return nil
        end
    end

    local result = distance[#lhs][#rhs]
    return result <= limit and result or nil
end
