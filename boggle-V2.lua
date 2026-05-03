local HttpService = game:GetService("HttpService")
local DICT_URL = "https://raw.githubusercontent.com/ItsXedy/word-hunt/refs/heads/main/WordList.txt"

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "BoggleSolver"
ScreenGui.Parent = game:GetService("CoreGui")
ScreenGui.ResetOnSpawn = false

-- Helper for sleek windows
local function createBox(name, size, pos, accent)
    local frame = Instance.new("Frame", ScreenGui)
    frame.Name = name
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

-- Create Windows
local Controls = createBox("Controls", UDim2.new(0, 160, 0, 220), UDim2.new(0.05, 0, 0.3, 0), Color3.fromRGB(0, 255, 136))
local Results = createBox("Results", UDim2.new(0, 140, 0, 280), UDim2.new(0.8, 0, 0.3, 0), Color3.fromRGB(255, 255, 255))

-- Toggle Button
local Toggle = Instance.new("TextButton", ScreenGui)
Toggle.Size = UDim2.new(0, 50, 0, 50)
Toggle.Position = UDim2.new(0, 10, 0.5, -25)
Toggle.BackgroundColor3 = Color3.fromRGB(0, 255, 136)
Toggle.Text = "H"
Toggle.Font = Enum.Font.SourceSansBold
Toggle.TextSize = 24
Toggle.Draggable = true
Instance.new("UICorner", Toggle).CornerRadius = UDim.new(0, 10)

Toggle.MouseButton1Click:Connect(function()
    Controls.Visible = not Controls.Visible
    Results.Visible = not Results.Visible
end)

-- UI Styling for Buttons
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
local currentTopWord = nil
local currentTopPath = {}

-- Controls Content
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

-- Results Scroll
local Scroll = Instance.new("ScrollingFrame", Results)
Scroll.Position = UDim2.new(0, 5, 0, 30)
Scroll.Size = UDim2.new(1, -10, 1, -40)
Scroll.BackgroundTransparency = 1
Scroll.ScrollBarThickness = 2
local List = Instance.new("UIListLayout", Scroll)

-- Solver & Pathfinding Logic
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
        Status.Text = "READY"
    else
        Status.Text = "ERROR"
    end
end)

local function getPieces()
    local pg = game:GetService("Players").LocalPlayer.PlayerGui
    return pg:FindFirstChild("ScreenGui") and pg.ScreenGui:FindFirstChild("PiecesFrame")
end

local function solve()
    local pieces = getPieces()
    if not pieces then return end
    
    local board = {}
    for r = 1, 4 do
        for c = 1, 4 do
            local p = pieces:FindFirstChild("R"..r.."C"..c)
            table.insert(board, p and p.TextLabel.Text:upper() or "")
        end
    end

    local found = {}
    local ds = {{-1,-1},{-1,0},{-1,1},{0,-1},{0,1},{1,-1},{1,0},{1,1}}
    
    local function dfs(idx, node, word, visited, path)
        if node.e and #word >= minLen and #word <= maxLen then
            if not found[word] or #path < #found[word].path then
                found[word] = {word = word, path = {unpack(path)}}
            end
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
        if board[i] ~= "" and Trie.c[board[i]] then 
            dfs(i, Trie.c[board[i]], board[i], {}, {i}) 
        end
    end

    -- Update Results
    for _, v in pairs(Scroll:GetChildren()) do if v:IsA("TextLabel") then v:Destroy() end end
    local sorted = {}
    for _, data in pairs(found) do table.insert(sorted, data) end
    table.sort(sorted, function(a,b) return #a.word > #b.word end)

    if #sorted > 0 then
        currentTopWord = sorted[1].word
        currentTopPath = sorted[1].path
    end

    for _, data in pairs(sorted) do
        local l = Instance.new("TextLabel", Scroll)
        l.Size = UDim2.new(1, 0, 0, 18); l.Text = data.word; l.TextColor3 = Color3.new(1,1,1)
        l.BackgroundTransparency = 1; l.Font = Enum.Font.Code; l.TextSize = 14; l.TextXAlignment = Enum.TextXAlignment.Left
    end
    Scroll.CanvasSize = UDim2.new(0,0,0, #sorted * 20)
end

-- Virtual Input Function
local function submitTop()
    if not currentTopPath or #currentTopPath == 0 then return end
    local pieces = getPieces()
    if not pieces then return end

    Status.Text = "Submitting: " .. currentTopWord
    
    for _, index in ipairs(currentTopPath) do
        local r = math.floor((index-1)/4) + 1
        local c = (index-1)%4 + 1
        local btn = pieces:FindFirstChild("R"..r.."C"..c)
        
        if btn then
            -- Simulate the click logic of the game
            -- This assumes the game uses standard button clicks or touches
            local pos = btn.AbsolutePosition + (btn.AbsoluteSize / 2)
            -- Use VirtualInputManager if your executor supports it, or just call the click
            if btn:FindFirstChild("Button") then -- Adjust if game uses a sub-button
                btn.Button:Activate()
            else
                -- Generic click simulation
                pcall(function()
                    for _, connection in pairs(getconnections(btn.MouseButton1Click)) do
                        connection:Fire()
                    end
                end)
            end
            task.wait(0.05) -- Tiny delay to look human/register
        end
    end
    -- Reset for next word
    currentTopPath = {}
    solve() -- Refresh list
end

SolveBtn.MouseButton1Click:Connect(solve)
SubmitBtn.MouseButton1Click:Connect(submitTop)