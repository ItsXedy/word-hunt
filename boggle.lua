local HttpService = game:GetService("HttpService")
local DICT_URL = "https://raw.githubusercontent.com/ItsXedy/word-hunt/refs/heads/main/WordList.txt"

-- GUI Setup
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "BoggleSolver"
ScreenGui.Parent = game:GetService("CoreGui")
ScreenGui.ResetOnSpawn = false

-- Main Window
local MainFrame = Instance.new("Frame")
MainFrame.Parent = ScreenGui
MainFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
MainFrame.BorderSizePixel = 2
MainFrame.BorderColor3 = Color3.fromRGB(60, 60, 60) -- Indicator border
MainFrame.Position = UDim2.new(0.5, -110, 0.5, -160)
MainFrame.Size = UDim2.new(0, 220, 0, 400) -- Increased height for sliders
MainFrame.Visible = false
MainFrame.Active = true
MainFrame.Draggable = true

-- DRAG HANDLE (Indicates where to move the box)
local DragHandle = Instance.new("Frame")
DragHandle.Size = UDim2.new(1, 0, 0, 20)
DragHandle.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
DragHandle.Parent = MainFrame
local DragLabel = Instance.new("TextLabel")
DragLabel.Size = UDim2.new(1, 0, 1, 0)
DragLabel.Text = ":::: HOLD TO MOVE ::::"
DragLabel.TextColor3 = Color3.fromRGB(100, 100, 100)
DragLabel.TextSize = 10
DragLabel.BackgroundTransparency = 1
DragLabel.Parent = DragHandle

-- Toggle Button
local Toggle = Instance.new("TextButton")
Toggle.Parent = ScreenGui
Toggle.Size = UDim2.new(0, 80, 0, 35)
Toggle.Position = UDim2.new(0, 10, 0.5, 0)
Toggle.BackgroundColor3 = Color3.fromRGB(0, 255, 136)
Toggle.BorderSizePixel = 2
Toggle.BorderColor3 = Color3.fromRGB(255, 255, 255) -- Border for move indication
Toggle.Text = "SOLVER"
Toggle.Font = Enum.Font.SourceSansBold
Toggle.Draggable = true -- Allows you to move the toggle button too
Toggle.MouseButton1Click:Connect(function() MainFrame.Visible = not MainFrame.Visible end)

-- Status
local Status = Instance.new("TextLabel")
Status.Parent = MainFrame
Status.Position = UDim2.new(0, 0, 0, 20)
Status.Size = UDim2.new(1, 0, 0, 30)
Status.Text = "Loading..."
Status.TextColor3 = Color3.new(1,1,1)
Status.BackgroundTransparency = 1

-- SLIDERS
local minLen = 3
local maxLen = 16

local function createSlider(name, pos, default, min, max)
    local label = Instance.new("TextLabel", MainFrame)
    label.Size = UDim2.new(1, 0, 0, 20)
    label.Position = pos
    label.Text = name .. ": " .. default
    label.TextColor3 = Color3.new(0.8, 0.8, 0.8)
    label.BackgroundTransparency = 1
    
    local btn = Instance.new("TextButton", label)
    btn.Size = UDim2.new(0.8, 0, 0, 15)
    btn.Position = UDim2.new(0.1, 0, 1, 0)
    btn.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    btn.Text = "Tap to Adjust"
    btn.TextColor3 = Color3.new(1,1,1)
    btn.TextSize = 10

    local val = default
    btn.MouseButton1Click:Connect(function()
        val = val + 1
        if val > max then val = min end
        label.Text = name .. ": " .. val
        if name == "Min" then minLen = val else maxLen = val end
    end)
    return label
end

createSlider("Min", UDim2.new(0, 0, 0, 50), 3, 2, 10)
createSlider("Max", UDim2.new(0, 0, 0, 90), 16, 3, 16)

-- Results List
local ResultsBox = Instance.new("ScrollingFrame")
ResultsBox.Parent = MainFrame
ResultsBox.Position = UDim2.new(0, 5, 0, 140)
ResultsBox.Size = UDim2.new(1, -10, 1, -185)
ResultsBox.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
ResultsBox.BorderSizePixel = 0
local UIListLayout = Instance.new("UIListLayout")
UIListLayout.Parent = ResultsBox

-- Solve Button
local SolveBtn = Instance.new("TextButton")
SolveBtn.Parent = MainFrame
SolveBtn.Position = UDim2.new(0, 5, 1, -40)
SolveBtn.Size = UDim2.new(1, -10, 0, 35)
SolveBtn.BackgroundColor3 = Color3.fromRGB(0, 255, 136)
SolveBtn.Text = "AUTO-SOLVE"
SolveBtn.Font = Enum.Font.SourceSansBold

-- DICTIONARY LOADING
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
        Status.Text = "LOAD FAILED!"
    end
end)

-- SOLVER LOGIC
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
    local visited = {}
    
    local function dfs(idx, node, word)
        if node.e and #word >= minLen and #word <= maxLen then found[word] = true end
        if #word >= maxLen then return end
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

    for _, v in pairs(ResultsBox:GetChildren()) do if v:IsA("TextLabel") then v:Destroy() end end
    local sorted = {}
    for w in pairs(found) do table.insert(sorted, w) end
    table.sort(sorted, function(a,b) return #a > #b end)
    
    for _, w in pairs(sorted) do
        local l = Instance.new("TextLabel", ResultsBox)
        l.Size = UDim2.new(1, 0, 0, 25)
        l.Text = w
        l.TextColor3 = Color3.new(1,1,1)
        l.BackgroundTransparency = 1
    end
    ResultsBox.CanvasSize = UDim2.new(0,0,0, #sorted * 25)
end

SolveBtn.MouseButton1Click:Connect(solve)