local HttpService = game:GetService("HttpService")
local VIM = game:GetService("VirtualInputManager")
local DICT_URL = "https://raw.githubusercontent.com/ItsXedy/word-hunt/refs/heads/main/WordList.txt"

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "BoggleSolver"
ScreenGui.Parent = game:GetService("CoreGui")
ScreenGui.ResetOnSpawn = false

-- UI Creator
local function createBox(name, size, pos, accent)
    local frame = Instance.new("Frame", ScreenGui)
    frame.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
    frame.BackgroundTransparency = 0.1
    frame.BorderSizePixel = 0
    frame.Position = pos
    frame.Size = size
    frame.Visible = false
    frame.Active = true
    frame.Draggable = true
    local border = Instance.new("Frame", frame)
    border.Size = UDim2.new(1, 0, 0, 2)
    border.BackgroundColor3 = accent
    border.BorderSizePixel = 0
    local title = Instance.new("TextLabel", frame)
    title.Size = UDim2.new(1, -10, 0, 25)
    title.Position = UDim2.new(0, 5, 0, 2)
    title.Text = name:upper()
    title.TextColor3 = Color3.new(1, 1, 1)
    title.TextSize = 13
    title.Font = Enum.Font.Code
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.BackgroundTransparency = 1
    return frame
end

local Controls = createBox("Controls", UDim2.new(0, 160, 0, 220), UDim2.new(0.05, 0, 0.3, 0), Color3.fromRGB(0, 255, 136))
local Results = createBox("Results", UDim2.new(0, 140, 0, 280), UDim2.new(0.8, 0, 0.3, 0), Color3.fromRGB(255, 255, 255))

local Toggle = Instance.new("TextButton", ScreenGui)
Toggle.Size = UDim2.new(0, 50, 0, 50)
Toggle.Position = UDim2.new(0, 10, 0.5, -25)
Toggle.BackgroundColor3 = Color3.fromRGB(0, 255, 136)
Toggle.Text = "H"
Toggle.Font = Enum.Font.SourceSansBold
Toggle.TextColor3 = Color3.new(0,0,0)
Toggle.TextSize = 24
Toggle.Draggable = true
Instance.new("UICorner", Toggle).CornerRadius = UDim.new(0, 10)
Toggle.MouseButton1Click:Connect(function()
    Controls.Visible = not Controls.Visible
    Results.Visible = not Results.Visible
end)

local function styleBtn(txt, pos, parent, color)
    local b = Instance.new("TextButton", parent)
    b.Size = UDim2.new(1, -20, 0, 30)
    b.Position = pos
    b.BackgroundColor3 = color or Color3.fromRGB(30, 30, 30)
    b.TextColor3 = color and Color3.new(0,0,0) or Color3.new(1,1,1)
    b.Text = txt
    b.Font = Enum.Font.Code
    b.TextSize = 12
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 4)
    return b
end

local minLen, maxLen = 3, 16
local currentTopPath = {}

local Status = Instance.new("TextLabel", Controls)
Status.Position = UDim2.new(0, 5, 0, 25)
Status.Size = UDim2.new(1, -10, 0, 20)
Status.Text = "Status: Loading..."
Status.TextColor3 = Color3.fromRGB(0, 255, 136)
Status.Font = Enum.Font.Code
Status.BackgroundTransparency = 1
Status.TextXAlignment = Enum.TextXAlignment.Left

local minBtn = styleBtn("MIN: 3", UDim2.new(0, 10, 0, 50), Controls)
minBtn.MouseButton1Click:Connect(function()
    minLen = minLen + 1
    if minLen > 8 then minLen = 2 end
    minBtn.Text = "MIN: " .. minLen
end)

local maxBtn = styleBtn("MAX: 16", UDim2.new(0, 10, 0, 85), Controls)
maxBtn.MouseButton1Click:Connect(function()
    maxLen = maxLen - 1
    if maxLen < 3 then maxLen = 16 end
    maxBtn.Text = "MAX: " .. maxLen
end)

local SubmitBtn = styleBtn("SUBMIT TOP", UDim2.new(0, 10, 0, 130), Controls, Color3.fromRGB(255, 255, 255))
local SolveBtn = styleBtn("AUTO-SOLVE", UDim2.new(0, 10, 0, 175), Controls, Color3.fromRGB(0, 255, 136))

local Scroll = Instance.new("ScrollingFrame", Results)
Scroll.Position = UDim2.new(0, 5, 0, 30)
Scroll.Size = UDim2.new(1, -10, 1, -40)
Scroll.BackgroundTransparency = 1
Scroll.ScrollBarThickness = 2
local List = Instance.new("UIListLayout", Scroll)

local Trie = {c = {}, e = false}
local function insert(word)
    local curr = Trie
    for i = 1, #word do
        local char = string.sub(word, i, i)
        if not curr.c[char] then curr.c[char] = {c = {}, e = false} end
        curr = curr.c[char]
    end
    curr.e = true
end

task.spawn(function()
    local success, result = pcall(function() return game:HttpGet(DICT_URL) end)
    if success then
        local data = HttpService:JSONDecode(result)
        for word, _ in pairs(data.Words or data) do insert(string.upper(word)) end
        Status.Text = "Status: READY"
    else
        Status.Text = "Status: LOAD ERROR"
    end
end)

local function getPieces()
    local pg = game:GetService("Players").LocalPlayer.PlayerGui
    -- Flexible search for the board
    local sg = pg:FindFirstChild("ScreenGui")
    if sg then
        return sg:FindFirstChild("PiecesFrame")
    end
    return nil
end

local function solve()
    local pieces = getPieces()
    if not pieces then Status.Text = "Status: BOARD ERROR"; return end
    
    local board = {}
    for r = 1, 4 do
        for c = 1, 4 do
            local p = pieces:FindFirstChild("R"..r.."C"..c)
            local label = p and p:FindFirstChild("TextLabel")
            table.insert(board, label and label.Text:upper() or "")
        end
    end

    local found = {}
    local ds = {{-1,-1},{-1,0},{-1,1},{0,-1},{0,1},{1,-1},{1,0},{1,1}}
    
    local function dfs(idx, node, word, visited, path)
        if node.e and #word >= minLen and #word <= maxLen then
            if not found[word] then found[word] = {word = word, path = {unpack(path)}} end
        end
        if #word >= maxLen then return end
        visited[idx] = true
        local r, c = math.floor((idx-1)/4), (idx-1)%4
        for _, d in pairs(ds) do
            local nr, nc = r + d[1], c + d[2]
            local ni = (nr * 4) + nc + 1
            if nr >= 0 and nr < 4 and nc >= 0 and nc < 4 and not visited[ni] then
                local char = board[ni]
                if char ~= "" and node.c[char] then
                    table.insert(path, ni)
                    dfs(ni, node.c[char], word .. char, visited, path)
                    table.remove(path)
                end
            end
        end
        visited[idx] = false
    end

    for i = 1, 16 do
        if board[i] ~= "" and Trie.c[board[i]] then dfs(i, Trie.c[board[i]], board[i], {}, {i}) end
    end

    for _, v in pairs(Scroll:GetChildren()) do if v:IsA("TextLabel") then v:Destroy() end end
    local sorted = {}
    for _, data in pairs(found) do table.insert(sorted, data) end
    table.sort(sorted, function(a,b) return #a.word > #b.word end)

    if #sorted > 0 then currentTopPath = sorted[1].path end

    for _, data in pairs(sorted) do
        local l = Instance.new("TextLabel", Scroll)
        l.Size = UDim2.new(1, 0, 0, 18); l.Text = data.word; l.TextColor3 = Color3.new(1,1,1)
        l.BackgroundTransparency = 1; l.Font = Enum.Font.Code; l.TextSize = 14; l.TextXAlignment = Enum.TextXAlignment.Left
    end
    Scroll.CanvasSize = UDim2.new(0,0,0, #sorted * 20)
    Status.Text = "Status: FOUND " .. #sorted
end

-- THE FIXED DRAG FUNCTION
local function submitTop()
    if not currentTopPath or #currentTopPath == 0 then return end
    local pieces = getPieces()
    if not pieces then Status.Text = "Status: NO TILES"; return end

    local tid = math.random(1000, 9999)
    Status.Text = "Status: SWIPING..."

    for i, index in ipairs(currentTopPath) do
        local r = math.floor((index-1)/4) + 1
        local c = (index-1)%4 + 1
        local tile = pieces:FindFirstChild("R"..r.."C"..c)
        
        if tile then
            local pos = tile.AbsolutePosition + (tile.AbsoluteSize / 2)
            
            if i == 1 then
                VIM:SendTouchEvent(tid, Enum.UserInputState.Begin, pos.X, pos.Y)
            else
                VIM:SendTouchEvent(tid, Enum.UserInputState.Change, pos.X, pos.Y)
            end
            
            -- Feedback highlight
            local old = tile.BackgroundColor3
            tile.BackgroundColor3 = Color3.new(1, 1, 1)
            task.delay(0.2, function() tile.BackgroundColor3 = old end)
            
            task.wait(0.04) 
        end
    end
    
    -- Lift up at the very last position
    local lastIdx = currentTopPath[#currentTopPath]
    local lr = math.floor((lastIdx-1)/4) + 1
    local lc = (lastIdx-1)%4 + 1
    local lastTile = pieces:FindFirstChild("R"..lr.."C"..lc)
    if lastTile then
        local lp = lastTile.AbsolutePosition + (lastTile.AbsoluteSize / 2)
        VIM:SendTouchEvent(tid, Enum.UserInputState.End, lp.X, lp.Y)
    end

    task.wait(0.1)
    solve()
    Status.Text = "Status: READY"
end

SolveBtn.MouseButton1Click:Connect(solve)
SubmitBtn.MouseButton1Click:Connect(submitTop)