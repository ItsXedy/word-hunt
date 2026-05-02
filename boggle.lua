local HttpService = game:GetService("HttpService")
local DICT_URL = "https://raw.githubusercontent.com/ItsXedy/word-hunt/refs/heads/main/WordList.txt" -- UPDATE THIS

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "BoggleSolverV3"
ScreenGui.Parent = game:GetService("CoreGui")
ScreenGui.ResetOnSpawn = false

-- Helper for Draggable behavior
local function makeDraggable(frame)
    frame.Active = true
    frame.Draggable = true
end

-- 1. FLOATING TOGGLE BUTTON
local Toggle = Instance.new("TextButton")
Toggle.Name = "Launcher"
Toggle.Parent = ScreenGui
Toggle.Size = UDim2.new(0, 60, 0, 60)
Toggle.Position = UDim2.new(0, 10, 0.5, 0)
Toggle.BackgroundColor3 = Color3.fromRGB(0, 255, 136)
Toggle.BackgroundTransparency = 0.3
Toggle.Text = "B"
Toggle.Font = Enum.Font.SourceSansBold
Toggle.TextSize = 30
Toggle.TextColor3 = Color3.new(0,0,0)
makeDraggable(Toggle)

local Corner = Instance.new("UICorner")
Corner.CornerRadius = UDim.new(1, 0)
Corner.Parent = Toggle

-- 2. LEFT MENU (Controls)
local LeftMenu = Instance.new("Frame")
LeftMenu.Name = "LeftMenu"
LeftMenu.Parent = ScreenGui
LeftMenu.Size = UDim2.new(0, 150, 0, 220)
LeftMenu.Position = UDim2.new(0.5, -220, 0.5, -110)
LeftMenu.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
LeftMenu.BackgroundTransparency = 0.5
LeftMenu.Visible = false
makeDraggable(LeftMenu)

-- 3. RIGHT BOX (Results)
local RightBox = Instance.new("Frame")
RightBox.Name = "RightBox"
RightBox.Parent = ScreenGui
RightBox.Size = UDim2.new(0, 180, 0, 350)
RightBox.Position = UDim2.new(0.5, -60, 0.5, -175)
RightBox.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
RightBox.BackgroundTransparency = 0.5
RightBox.Visible = false
makeDraggable(RightBox)

-- Toggle Logic
Toggle.MouseButton1Click:Connect(function()
    LeftMenu.Visible = not LeftMenu.Visible
    RightBox.Visible = LeftMenu.Visible
end)

-- LEFT MENU CONTENT
local Status = Instance.new("TextLabel", LeftMenu)
Status.Size = UDim2.new(1, 0, 0, 30)
Status.Text = "Loading..."
Status.TextColor3 = Color3.new(1,1,1)
Status.BackgroundTransparency = 1

local RefreshBtn = Instance.new("TextButton", LeftMenu)
RefreshBtn.Size = UDim2.new(0.9, 0, 0, 40)
RefreshBtn.Position = UDim2.new(0.05, 0, 0, 40)
RefreshBtn.BackgroundColor3 = Color3.fromRGB(0, 255, 136)
RefreshBtn.Text = "REFRESH"
RefreshBtn.Font = Enum.Font.SourceSansBold

-- Length Filter UI
local MinLabel = Instance.new("TextLabel", LeftMenu)
MinLabel.Position = UDim2.new(0, 10, 0, 90)
MinLabel.Text = "Min Length: 3"
MinLabel.TextColor3 = Color3.new(1,1,1)
MinLabel.Size = UDim2.new(1, -20, 0, 20)
MinLabel.BackgroundTransparency = 1

local MinInput = Instance.new("TextBox", LeftMenu)
MinInput.Position = UDim2.new(0.1, 0, 0, 115)
MinInput.Size = UDim2.new(0.8, 0, 0, 30)
MinInput.Text = "3"
MinInput.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
MinInput.TextColor3 = Color3.new(1,1,1)

-- RIGHT BOX CONTENT
local Scroll = Instance.new("ScrollingFrame", RightBox)
Scroll.Size = UDim2.new(1, -10, 1, -10)
Scroll.Position = UDim2.new(0, 5, 0, 5)
Scroll.BackgroundTransparency = 1
Scroll.CanvasSize = UDim2.new(0,0,0,0)
local List = Instance.new("UIListLayout", Scroll)

-- SOLVER CORE
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
        Status.Text = "READY: " .. count
    else
        Status.Text = "LOAD ERROR"
    end
end)

local function getBoard()
    local board = {}
    local pieces = game:GetService("Players").LocalPlayer.PlayerGui:FindFirstChild("ScreenGui"):FindFirstChild("PiecesFrame")
    if pieces then
        for r = 1, 4 do
            for c = 1, 4 do
                local name = "R" .. r .. "C" .. c
                local p = pieces:FindFirstChild(name)
                local txt = p and p:FindFirstChild("TextLabel") and p.TextLabel.Text or ""
                table.insert(board, string.upper(txt))
            end
        end
    end
    return board
end

local ds = {{-1,-1},{-1,0},{-1,1},{0,-1},{0,1},{1,-1},{1,0},{1,1}}

local function solve()
    local board = getBoard()
    local found = {}
    local visited = {}
    local minLen = tonumber(MinInput.Text) or 3

    local function dfs(idx, node, word)
        if node.e and #word >= minLen then found[word] = true end
        if #word >= 16 then return end
        visited[idx] = true
        local r, c = math.floor((idx-1)/4), (idx-1)%4
        for _, d in pairs(ds) do
            local nr, nc = r + d[1], c + d[2]
            local ni = (nr * 4) + nc + 1
            if nr >= 0 and nr < 4 and nc >= 0 and nc < 4 and not visited[ni] then
                local char = board[ni]
                if char ~= "" and node.c[char] then dfs(ni, node.c[char], word .. char) end
            end
        end
        visited[idx] = false
    end

    for i = 1, 16 do
        if board[i] ~= "" and Trie.c[board[i]] then dfs(i, Trie.c[board[i]], board[i]) end
    end

    for _, v in pairs(Scroll:GetChildren()) do if v:IsA("TextLabel") then v:Destroy() end end
    local sorted = {}
    for w in pairs(found) do table.insert(sorted, w) end
    table.sort(sorted, function(a,b) return #a > #b end)
    
    for _, w in pairs(sorted) do
        local l = Instance.new("TextLabel", Scroll)
        l.Size = UDim2.new(1, 0, 0, 30)
        l.Text = w
        l.TextColor3 = Color3.fromRGB(0, 255, 136)
        l.BackgroundTransparency = 1
        l.TextSize = 18
    end
    Scroll.CanvasSize = UDim2.new(0, 0, 0, #sorted * 30)
end

RefreshBtn.MouseButton1Click:Connect(solve)
MinInput:GetPropertyChangedSignal("Text"):Connect(function()
    MinLabel.Text = "Min Length: " .. (tonumber(MinInput.Text) or 3)
end)