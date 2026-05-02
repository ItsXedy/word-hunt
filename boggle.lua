local HttpService = game:GetService("HttpService")
local DICT_URL = "https://raw.githubusercontent.com/ItsXedy/word-hunt/refs/heads/main/WordList.txt"

-- GUI Setup
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "BoggleSolver"
ScreenGui.Parent = game:GetService("CoreGui")
ScreenGui.ResetOnSpawn = false

-- Function to create a styled window
local function createWindow(name, size, pos)
    local frame = Instance.new("Frame")
    frame.Name = name
    frame.Parent = ScreenGui
    frame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    frame.BorderSizePixel = 2
    frame.BorderColor3 = Color3.fromRGB(60, 60, 60)
    frame.Position = pos
    frame.Size = size
    frame.Visible = false
    frame.Active = true
    frame.Draggable = true

    local handle = Instance.new("Frame")
    handle.Size = UDim2.new(1, 0, 0, 18)
    handle.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
    handle.Parent = frame

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 1, 0)
    label.Text = name:upper() .. " (DRAG HERE)"
    label.TextColor3 = Color3.fromRGB(150, 150, 150)
    label.TextSize = 10
    label.BackgroundTransparency = 1
    label.Parent = handle

    return frame
end

-- Create the two boxes
local ControlFrame = createWindow("Controls", UDim2.new(0, 180, 0, 160), UDim2.new(0.1, 0, 0.2, 0))
local ResultsFrame = createWindow("Results", UDim2.new(0, 160, 0, 250), UDim2.new(0.1, 0, 0.45, 0))

-- Toggle Button
local Toggle = Instance.new("TextButton")
Toggle.Parent = ScreenGui
Toggle.Size = UDim2.new(0, 70, 0, 30)
Toggle.Position = UDim2.new(0, 5, 0.5, 0)
Toggle.BackgroundColor3 = Color3.fromRGB(0, 255, 136)
Toggle.BorderSizePixel = 2
Toggle.Text = "SOLVER"
Toggle.Font = Enum.Font.SourceSansBold
Toggle.Draggable = true
Toggle.MouseButton1Click:Connect(function()
    local visible = not ControlFrame.Visible
    ControlFrame.Visible = visible
    ResultsFrame.Visible = visible
end)

-- Status
local Status = Instance.new("TextLabel", ControlFrame)
Status.Position = UDim2.new(0, 0, 0, 20)
Status.Size = UDim2.new(1, 0, 0, 25)
Status.Text = "Loading..."
Status.TextColor3 = Color3.new(0, 1, 0.5)
Status.BackgroundTransparency = 1
Status.TextSize = 12

-- Sliders
local minLen, maxLen = 3, 16
local function addBtn(txt, pos, callback)
    local btn = Instance.new("TextButton", ControlFrame)
    btn.Size = UDim2.new(0.9, 0, 0, 25)
    btn.Position = pos
    btn.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    btn.TextColor3 = Color3.new(1,1,1)
    btn.Text = txt
    btn.Font = Enum.Font.SourceSans
    btn.MouseButton1Click:Connect(callback)
    return btn
end

local minBtn = addBtn("Min Length: 3", UDim2.new(0.05, 0, 0, 50), function()
    minLen = minLen + 1
    if minLen > 10 then minLen = 2 end
    ControlFrame.minBtn.Text = "Min Length: " .. minLen
end)
ControlFrame:FindFirstChild("TextButton").Name = "minBtn" -- Ref for the callback

local maxBtn = addBtn("Max Length: 16", UDim2.new(0.05, 0, 0, 80), function()
    maxLen = maxLen - 1
    if maxLen < 3 then maxLen = 16 end
    ControlFrame.maxBtn.Text = "Max Length: " .. maxLen
end)
-- Quick fix for naming to ensure buttons don't conflict
local btns = ControlFrame:GetChildren()
btns[#btns].Name = "maxBtn"

local SolveBtn = addBtn("AUTO-SOLVE", UDim2.new(0.05, 0, 0, 120), nil)
SolveBtn.BackgroundColor3 = Color3.fromRGB(0, 255, 136)
SolveBtn.TextColor3 = Color3.new(0,0,0)
SolveBtn.Font = Enum.Font.SourceSansBold

-- Results List
local Scroll = Instance.new("ScrollingFrame", ResultsFrame)
Scroll.Position = UDim2.new(0, 5, 0, 25)
Scroll.Size = UDim2.new(1, -10, 1, -30)
Scroll.BackgroundTransparency = 1
Scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
Scroll.ScrollBarThickness = 4
local List = Instance.new("UIListLayout", Scroll)

-- Dictionary Logic
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
        local count = 0
        for word, _ in pairs(data.Words or data) do
            insert(string.upper(word))
            count = count + 1
        end
        Status.Text = "READY: " .. count .. " WORDS"
    else
        Status.Text = "LOAD ERROR"
    end
end)

local function getBoard()
    local board = {}
    local pg = game:GetService("Players").LocalPlayer.PlayerGui
    local pieces = pg:FindFirstChild("ScreenGui") and pg.ScreenGui:FindFirstChild("PiecesFrame")
    if pieces then
        for r = 1, 4 do
            for c = 1, 4 do
                local p = pieces:FindFirstChild("R"..r.."C"..c)
                local l = p and p:FindFirstChild("TextLabel") and p.TextLabel.Text or ""
                table.insert(board, string.upper(l))
            end
        end
    end
    return board
end

local ds = {{-1,-1},{-1,0},{-1,1},{0,-1},{0,1},{1,-1},{1,0},{1,1}}
local function solve()
    local board = getBoard()
    local found = {}
    local function dfs(idx, node, word, visited)
        if node.e and #word >= minLen and #word <= maxLen then found[word] = true end
        if #word >= maxLen then return end
        visited[idx] = true
        local r, c = math.floor((idx-1)/4), (idx-1)%4
        for _, d in pairs(ds) do
            local nr, nc = r + d[1], c + d[2]
            local ni = (nr * 4) + nc + 1
            if nr >= 0 and nr < 4 and nc >= 0 and nc < 4 and not visited[ni] then
                local char = board[ni]
                if char ~= "" and node.c[char] then
                    local newVisited = {unpack(visited)}
                    dfs(ni, node.c[char], word .. char, visited)
                end
            end
        end
        visited[idx] = false
    end

    for i = 1, 16 do
        if board[i] ~= "" and Trie.c[board[i]] then dfs(i, Trie.c[board[i]], board[i], {}) end
    end

    for _, v in pairs(Scroll:GetChildren()) do if v:IsA("TextLabel") then v:Destroy() end end
    local sorted = {}
    for w in pairs(found) do table.insert(sorted, w) end
    table.sort(sorted, function(a,b) return #a > #b or (#a == #b and a < b) end)
    
    for _, w in pairs(sorted) do
        local l = Instance.new("TextLabel", Scroll)
        l.Size = UDim2.new(1, 0, 0, 20)
        l.Text = w
        l.TextColor3 = Color3.new(1,1,1)
        l.BackgroundTransparency = 1
        l.TextSize = 14
    end
    Scroll.CanvasSize = UDim2.new(0,0,0, #sorted * 20)
end

SolveBtn.MouseButton1Click:Connect(solve)