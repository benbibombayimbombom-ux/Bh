-- ============================================================
--  BROOKHAVEN HAIR COLOR ADJUSTER  v2  (Compact 300×300)
--  LocalScript — StarterPlayerScripts veya executor
-- ============================================================

local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService  = game:GetService("UserInputService")
local TweenService      = game:GetService("TweenService")

local player    = Players.LocalPlayer
local playerGui = player.PlayerGui

local Remotes           = ReplicatedStorage:WaitForChild("Remotes")
local SetAccessoryColor = Remotes:WaitForChild("SetAccessoryColor")

-- ──────────────────────────────────────────────────────────
--  STATE
-- ──────────────────────────────────────────────────────────
local allHairs     = {}
local selectedHair = nil
local curH, curS, curV = 0.85, 1, 1        -- HSV
local rgbMode      = false
local rgbHue       = 0
local lastApply    = 0

local function hsvToRgb(h, s, v)
    return Color3.fromHSV(h, s, v)
end

local function getAssetId(acc)
    local id = acc:GetAttribute("AssetId") or acc:GetAttribute("assetId")
    if id then return id end
    local h = acc:FindFirstChild("Handle")
    if not h then return nil end
    id = h:GetAttribute("AssetId") or h:GetAttribute("assetId")
    if id then return id end
    local sm = h:FindFirstChildOfClass("SpecialMesh")
    if sm and sm.MeshId and sm.MeshId ~= "" then
        local n = sm.MeshId:match("%d+")
        if n then return tonumber(n) end
    end
    if h:IsA("MeshPart") and h.MeshId ~= "" then
        local n = h.MeshId:match("%d+")
        if n then return tonumber(n) end
    end
    return nil
end

local function applyColor(hd, col)
    if not hd or not hd.id then return end
    pcall(function()
        SetAccessoryColor:InvokeServer(hd.id, {
            color = { r = col.R, g = col.G, b = col.B }
        })
    end)
end

local function applyToAll(col)
    for _, hd in ipairs(allHairs) do applyColor(hd, col) end
end

local function scanHairs()
    allHairs = {}
    selectedHair = nil
    local char = player.Character
    if not char then return end
    for _, c in ipairs(char:GetChildren()) do
        if c:IsA("Accessory") then
            table.insert(allHairs, { accessory = c, id = getAssetId(c), name = c.Name })
        end
    end
end

-- ──────────────────────────────────────────────────────────
--  CLEAN OLD
-- ──────────────────────────────────────────────────────────
if playerGui:FindFirstChild("HCA2") then playerGui.HCA2:Destroy() end

-- ──────────────────────────────────────────────────────────
--  SCREEN GUI
-- ──────────────────────────────────────────────────────────
local sg = Instance.new("ScreenGui")
sg.Name           = "HCA2"
sg.ResetOnSpawn   = false
sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
sg.IgnoreGuiInset = true
sg.Parent         = playerGui

-- ──────────────────────────────────────────────────────────
--  MAIN FRAME  310 × 310
-- ──────────────────────────────────────────────────────────
local W, H = 310, 310
local BAR   = 32

local main = Instance.new("Frame")
main.Name             = "Main"
main.Size             = UDim2.new(0, W, 0, H)
main.Position         = UDim2.new(0.5, -W/2, 0.5, -H/2)
main.BackgroundColor3 = Color3.fromRGB(10, 10, 16)
main.BorderSizePixel  = 0
main.ClipsDescendants = true
main.Parent           = sg
Instance.new("UICorner", main).CornerRadius = UDim.new(0, 12)

local mainStroke = Instance.new("UIStroke")
mainStroke.Color       = Color3.fromRGB(140, 45, 230)
mainStroke.Thickness   = 1.5
mainStroke.Parent      = main

-- ──────────────────────────────────────────────────────────
--  TITLE BAR
-- ──────────────────────────────────────────────────────────
local bar = Instance.new("Frame")
bar.Size             = UDim2.new(1, 0, 0, BAR)
bar.BackgroundColor3 = Color3.fromRGB(16, 16, 26)
bar.BorderSizePixel  = 0
bar.ZIndex           = 8
bar.Parent           = main

local barGrad = Instance.new("UIGradient")
barGrad.Color    = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(60, 18, 110)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(16, 16, 26)),
})
barGrad.Rotation = 90
barGrad.Parent   = bar

local titleL = Instance.new("TextLabel")
titleL.Size               = UDim2.new(1, -80, 1, 0)
titleL.Position           = UDim2.new(0, 10, 0, 0)
titleL.BackgroundTransparency = 1
titleL.Text               = "✦ Hair Recolor"
titleL.TextColor3         = Color3.fromRGB(220, 220, 255)
titleL.TextSize           = 12
titleL.Font               = Enum.Font.GothamBold
titleL.TextXAlignment     = Enum.TextXAlignment.Left
titleL.ZIndex             = 9
titleL.Parent             = bar

local function mkTBtn(icon, col, xOff)
    local b = Instance.new("TextButton")
    b.Size             = UDim2.new(0, 22, 0, 22)
    b.Position         = UDim2.new(1, xOff, 0.5, -11)
    b.BackgroundColor3 = col
    b.Text             = icon
    b.TextColor3       = Color3.fromRGB(255,255,255)
    b.TextSize         = 11
    b.Font             = Enum.Font.GothamBold
    b.BorderSizePixel  = 0
    b.ZIndex           = 9
    b.Parent           = bar
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 5)
    return b
end

local minBtn   = mkTBtn("−", Color3.fromRGB(180,120,20), -50)
local closeBtn = mkTBtn("✕", Color3.fromRGB(190,40,40),  -24)

-- Drag
local dragging, dragStart, dragOrigin = false, nil, nil
bar.InputBegan:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
        dragging = true; dragStart = i.Position; dragOrigin = main.Position
        i.Changed:Connect(function()
            if i.UserInputState == Enum.UserInputState.End then dragging = false end
        end)
    end
end)
UserInputService.InputChanged:Connect(function(i)
    if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
        local d = i.Position - dragStart
        main.Position = UDim2.new(dragOrigin.X.Scale, dragOrigin.X.Offset+d.X, dragOrigin.Y.Scale, dragOrigin.Y.Offset+d.Y)
    end
end)

-- ──────────────────────────────────────────────────────────
--  CONTENT
-- ──────────────────────────────────────────────────────────
local content = Instance.new("Frame")
content.Size             = UDim2.new(1, 0, 1, -BAR)
content.Position         = UDim2.new(0, 0, 0, BAR)
content.BackgroundTransparency = 1
content.Parent           = main

-- ──────────────────────────────────────────────────────────
--  LEFT: Aksesuar Listesi (küçük dikey scroll)  ~110px geniş
-- ──────────────────────────────────────────────────────────
local LEFT = 112

local scanBtn = Instance.new("TextButton")
scanBtn.Size             = UDim2.new(0, LEFT-4, 0, 18)
scanBtn.Position         = UDim2.new(0, 2, 0, 3)
scanBtn.BackgroundColor3 = Color3.fromRGB(20, 60, 30)
scanBtn.Text             = "↺ Scan"
scanBtn.TextColor3       = Color3.fromRGB(55, 210, 85)
scanBtn.TextSize         = 10
scanBtn.Font             = Enum.Font.GothamBold
scanBtn.BorderSizePixel  = 0
scanBtn.Parent           = content
Instance.new("UICorner", scanBtn).CornerRadius = UDim.new(0, 4)

local scroll = Instance.new("ScrollingFrame")
scroll.Size                 = UDim2.new(0, LEFT-4, 1, -28)
scroll.Position             = UDim2.new(0, 2, 0, 23)
scroll.BackgroundColor3     = Color3.fromRGB(13, 13, 20)
scroll.BorderSizePixel      = 0
scroll.ScrollBarThickness   = 2
scroll.ScrollBarImageColor3 = Color3.fromRGB(130, 50, 230)
scroll.CanvasSize           = UDim2.new(0, 0, 0, 0)
scroll.ScrollingDirection   = Enum.ScrollingDirection.Y
scroll.Parent               = content
Instance.new("UICorner", scroll).CornerRadius = UDim.new(0, 6)

local listLay = Instance.new("UIListLayout")
listLay.Padding            = UDim.new(0, 3)
listLay.SortOrder          = Enum.SortOrder.LayoutOrder
listLay.HorizontalAlignment= Enum.HorizontalAlignment.Center
listLay.Parent             = scroll

local listPad = Instance.new("UIPadding")
listPad.PaddingTop = UDim.new(0, 4)
listPad.Parent     = scroll

-- ──────────────────────────────────────────────────────────
--  DIVIDER
-- ──────────────────────────────────────────────────────────
local div = Instance.new("Frame")
div.Size             = UDim2.new(0, 1, 1, -6)
div.Position         = UDim2.new(0, LEFT, 0, 3)
div.BackgroundColor3 = Color3.fromRGB(50, 20, 80)
div.BorderSizePixel  = 0
div.Parent           = content

-- ──────────────────────────────────────────────────────────
--  RIGHT: Color Picker + Butonlar
-- ──────────────────────────────────────────────────────────
local RX = LEFT + 5
local RW  = W - LEFT - 8

-- ── Renk önizleme şeridi ──────────────────
local previewBar = Instance.new("Frame")
previewBar.Size             = UDim2.new(0, RW, 0, 16)
previewBar.Position         = UDim2.new(0, RX, 0, 3)
previewBar.BackgroundColor3 = Color3.fromHSV(curH, curS, curV)
previewBar.BorderSizePixel  = 0
previewBar.Parent           = content
Instance.new("UICorner", previewBar).CornerRadius = UDim.new(0, 4)

local hexLbl = Instance.new("TextLabel")
hexLbl.Size               = UDim2.new(1, -4, 1, 0)
hexLbl.BackgroundTransparency = 1
hexLbl.Text               = "#FF00FF"
hexLbl.TextColor3         = Color3.fromRGB(255,255,255)
hexLbl.TextSize           = 9
hexLbl.Font               = Enum.Font.GothamBold
hexLbl.TextXAlignment     = Enum.TextXAlignment.Right
hexLbl.ZIndex             = 2
hexLbl.Parent             = previewBar

-- ──────────────────────────────────────────────────────────
--  SV SQUARE (Saturation × Value picker)
-- ──────────────────────────────────────────────────────────
local SQ = RW          -- kare boyutu
local SQY = 22         -- y offset content içinde

local svFrame = Instance.new("Frame")
svFrame.Name             = "SVSquare"
svFrame.Size             = UDim2.new(0, SQ, 0, SQ - 10)
svFrame.Position         = UDim2.new(0, RX, 0, SQY)
svFrame.BackgroundColor3 = Color3.fromHSV(curH, 1, 1)
svFrame.BorderSizePixel  = 0
svFrame.ClipsDescendants = true
svFrame.Parent           = content
Instance.new("UICorner", svFrame).CornerRadius = UDim.new(0, 5)

-- White gradient (left→right: white→transparent)
local wGrad = Instance.new("UIGradient")
wGrad.Color    = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(255,255,255)),
    ColorSequenceKeypoint.new(1, Color3.new(1,1,1)),
})
wGrad.Transparency = NumberSequence.new({
    NumberSequenceKeypoint.new(0, 0),
    NumberSequenceKeypoint.new(1, 1),
})
wGrad.Parent = svFrame

-- Black overlay (top transparent → bottom black)
local blackOverlay = Instance.new("Frame")
blackOverlay.Size             = UDim2.new(1, 0, 1, 0)
blackOverlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
blackOverlay.BorderSizePixel  = 0
blackOverlay.ZIndex           = 2
Instance.new("UICorner", blackOverlay).CornerRadius = UDim.new(0, 5)
local bGrad = Instance.new("UIGradient")
bGrad.Transparency = NumberSequence.new({
    NumberSequenceKeypoint.new(0, 1),
    NumberSequenceKeypoint.new(1, 0),
})
bGrad.Rotation = 270
bGrad.Parent   = blackOverlay
blackOverlay.Parent = svFrame

-- SV thumb
local svThumb = Instance.new("Frame")
svThumb.Size             = UDim2.new(0, 10, 0, 10)
svThumb.AnchorPoint      = Vector2.new(0.5, 0.5)
svThumb.BackgroundColor3 = Color3.fromRGB(255,255,255)
svThumb.BorderSizePixel  = 0
svThumb.ZIndex           = 5
svThumb.Position         = UDim2.new(curS, 0, 1-curV, 0)
Instance.new("UICorner", svThumb).CornerRadius = UDim.new(1, 0)
local svStroke = Instance.new("UIStroke")
svStroke.Color     = Color3.fromRGB(30,30,30)
svStroke.Thickness = 1.5
svStroke.Parent    = svThumb
svThumb.Parent     = svFrame

-- ──────────────────────────────────────────────────────────
--  HUE STRIP
-- ──────────────────────────────────────────────────────────
local HUE_H = 10
local HUE_Y = SQY + SQ - 8

local hueFrame = Instance.new("Frame")
hueFrame.Size             = UDim2.new(0, SQ, 0, HUE_H)
hueFrame.Position         = UDim2.new(0, RX, 0, HUE_Y)
hueFrame.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
hueFrame.BorderSizePixel  = 0
hueFrame.ClipsDescendants = true
hueFrame.Parent           = content
Instance.new("UICorner", hueFrame).CornerRadius = UDim.new(0, 4)

-- 7-keypoint hue gradient
local hueGrad = Instance.new("UIGradient")
hueGrad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0,     Color3.fromHSV(0,   1, 1)),
    ColorSequenceKeypoint.new(0.167, Color3.fromHSV(0.167,1,1)),
    ColorSequenceKeypoint.new(0.333, Color3.fromHSV(0.333,1,1)),
    ColorSequenceKeypoint.new(0.5,   Color3.fromHSV(0.5, 1, 1)),
    ColorSequenceKeypoint.new(0.667, Color3.fromHSV(0.667,1,1)),
    ColorSequenceKeypoint.new(0.833, Color3.fromHSV(0.833,1,1)),
    ColorSequenceKeypoint.new(1,     Color3.fromHSV(1,   1, 1)),
})
hueGrad.Parent = hueFrame

-- Hue thumb
local hueThumb = Instance.new("Frame")
hueThumb.Size             = UDim2.new(0, 4, 1, 4)
hueThumb.AnchorPoint      = Vector2.new(0.5, 0.5)
hueThumb.Position         = UDim2.new(curH, 0, 0.5, 0)
hueThumb.BackgroundColor3 = Color3.fromRGB(255,255,255)
hueThumb.BorderSizePixel  = 0
hueThumb.ZIndex           = 3
Instance.new("UICorner", hueThumb).CornerRadius = UDim.new(0, 2)
local hStroke = Instance.new("UIStroke")
hStroke.Color     = Color3.fromRGB(30,30,30)
hStroke.Thickness = 1
hStroke.Parent    = hueThumb
hueThumb.Parent   = hueFrame

-- ──────────────────────────────────────────────────────────
--  BUTONLAR (3 küçük)
-- ──────────────────────────────────────────────────────────
local BTN_Y = HUE_Y + HUE_H + 6
local btnW   = math.floor((RW - 8) / 3)

local function mkBtn(text, bg, xi)
    local b = Instance.new("TextButton")
    b.Size             = UDim2.new(0, btnW, 0, 22)
    b.Position         = UDim2.new(0, RX + xi*(btnW+4), 0, BTN_Y)
    b.BackgroundColor3 = bg
    b.Text             = text
    b.TextColor3       = Color3.fromRGB(255,255,255)
    b.TextSize         = 9
    b.Font             = Enum.Font.GothamBold
    b.BorderSizePixel  = 0
    b.AutoButtonColor  = false
    b.Parent           = content
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 5)
    b.MouseEnter:Connect(function()
        TweenService:Create(b, TweenInfo.new(0.1), {BackgroundColor3 = bg:lerp(Color3.fromRGB(255,255,255),0.15)}):Play()
    end)
    b.MouseLeave:Connect(function()
        TweenService:Create(b, TweenInfo.new(0.1), {BackgroundColor3 = bg}):Play()
    end)
    return b
end

local colorBtn    = mkBtn("🎨Color",    Color3.fromRGB(35, 80, 200), 0)
local colorAllBtn = mkBtn("✦All",       Color3.fromRGB(90, 30, 180), 1)
local rgbBtn      = mkBtn("🌈RGB:OFF",  Color3.fromRGB(35, 35, 50),  2)

-- ──────────────────────────────────────────────────────────
--  STATUS (tek satır altta)
-- ──────────────────────────────────────────────────────────
local statusLbl = Instance.new("TextLabel")
statusLbl.Size               = UDim2.new(0, RW, 0, 14)
statusLbl.Position           = UDim2.new(0, RX, 1, -16)
statusLbl.BackgroundTransparency = 1
statusLbl.Text               = "Scan → Seç → Renklendir"
statusLbl.TextColor3         = Color3.fromRGB(110, 110, 145)
statusLbl.TextSize           = 9
statusLbl.Font               = Enum.Font.Gotham
statusLbl.TextXAlignment     = Enum.TextXAlignment.Left
statusLbl.TextTruncate       = Enum.TextTruncate.AtEnd
statusLbl.Parent             = content

local function setStatus(msg, col)
    statusLbl.Text       = msg
    statusLbl.TextColor3 = col or Color3.fromRGB(110, 110, 145)
end

-- ──────────────────────────────────────────────────────────
--  RENK GÜNCELLE
-- ──────────────────────────────────────────────────────────
local function refreshColor()
    local col = Color3.fromHSV(curH, curS, curV)
    -- Preview
    previewBar.BackgroundColor3 = col
    local function toHex(c)
        return string.format("#%02X%02X%02X", math.floor(c.R*255), math.floor(c.G*255), math.floor(c.B*255))
    end
    hexLbl.Text = toHex(col)
    -- SV square zemin rengi = tam doygun-full bright hue
    svFrame.BackgroundColor3 = Color3.fromHSV(curH, 1, 1)
    -- Thumblar
    svThumb.Position  = UDim2.new(curS, 0, 1 - curV, 0)
    hueThumb.Position = UDim2.new(curH, 0, 0.5, 0)
end

-- ──────────────────────────────────────────────────────────
--  PICKER INPUT
-- ──────────────────────────────────────────────────────────
local svDrag, hueDrag = false, false

svFrame.InputBegan:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
        svDrag = true
        local rel = svFrame.AbsolutePosition
        local sz  = svFrame.AbsoluteSize
        curS = math.clamp((i.Position.X - rel.X) / sz.X, 0, 1)
        curV = math.clamp(1 - (i.Position.Y - rel.Y) / sz.Y, 0, 1)
        refreshColor()
    end
end)

hueFrame.InputBegan:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
        hueDrag = true
        curH = math.clamp((i.Position.X - hueFrame.AbsolutePosition.X) / hueFrame.AbsoluteSize.X, 0, 1)
        refreshColor()
    end
end)

UserInputService.InputChanged:Connect(function(i)
    if i.UserInputType ~= Enum.UserInputType.MouseMovement and i.UserInputType ~= Enum.UserInputType.Touch then return end
    if svDrag then
        local rel = svFrame.AbsolutePosition
        local sz  = svFrame.AbsoluteSize
        curS = math.clamp((i.Position.X - rel.X) / sz.X, 0, 1)
        curV = math.clamp(1 - (i.Position.Y - rel.Y) / sz.Y, 0, 1)
        refreshColor()
    end
    if hueDrag then
        curH = math.clamp((i.Position.X - hueFrame.AbsolutePosition.X) / hueFrame.AbsoluteSize.X, 0, 1)
        refreshColor()
    end
end)

UserInputService.InputEnded:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
        svDrag = false; hueDrag = false
    end
end)

-- ──────────────────────────────────────────────────────────
--  KART BUILDER (liste)
-- ──────────────────────────────────────────────────────────
local cardMap = {}

local function deselectAll()
    for card in pairs(cardMap) do
        card.BackgroundColor3 = Color3.fromRGB(16, 16, 26)
        local s = card:FindFirstChildOfClass("UIStroke")
        if s then s.Color = Color3.fromRGB(35,35,55); s.Thickness = 1 end
    end
end

local function buildCard(hd, idx)
    local card = Instance.new("TextButton")
    card.Size             = UDim2.new(1, -4, 0, 48)
    card.BackgroundColor3 = Color3.fromRGB(16, 16, 26)
    card.Text             = ""
    card.BorderSizePixel  = 0
    card.LayoutOrder      = idx
    card.AutoButtonColor  = false
    card.Parent           = scroll
    Instance.new("UICorner", card).CornerRadius = UDim.new(0, 6)
    local cs = Instance.new("UIStroke")
    cs.Color = Color3.fromRGB(35,35,55); cs.Thickness = 1; cs.Parent = card

    -- ViewportFrame mini
    local vp = Instance.new("ViewportFrame")
    vp.Size             = UDim2.new(0, 40, 0, 40)
    vp.Position         = UDim2.new(0, 3, 0.5, -20)
    vp.BackgroundColor3 = Color3.fromRGB(10,10,15)
    vp.BorderSizePixel  = 0
    vp.ZIndex           = 2
    vp.Parent           = card
    Instance.new("UICorner", vp).CornerRadius = UDim.new(0, 5)

    local clone = hd.accessory:Clone()
    local handle = clone:FindFirstChild("Handle")
    if handle then
        handle.CFrame = CFrame.new(0,0,0)
        if handle:IsA("BasePart") then handle.Anchored = true end
        for _, w in ipairs(handle:GetChildren()) do
            if w:IsA("Weld") or w:IsA("WeldConstraint") or w:IsA("Motor6D") then w:Destroy() end
        end
    end
    clone.Parent = vp
    local cam = Instance.new("Camera")
    cam.FieldOfView = 50
    cam.CFrame      = CFrame.new(Vector3.new(0,0.3,2.2), Vector3.new(0,0.3,0))
    cam.Parent      = vp
    vp.CurrentCamera = cam

    local nameLbl = Instance.new("TextLabel")
    nameLbl.Size               = UDim2.new(1, -50, 0, 14)
    nameLbl.Position           = UDim2.new(0, 47, 0, 6)
    nameLbl.BackgroundTransparency = 1
    nameLbl.Text               = hd.name
    nameLbl.TextColor3         = Color3.fromRGB(215,215,235)
    nameLbl.TextSize           = 9
    nameLbl.Font               = Enum.Font.GothamBold
    nameLbl.TextXAlignment     = Enum.TextXAlignment.Left
    nameLbl.TextTruncate       = Enum.TextTruncate.AtEnd
    nameLbl.ZIndex             = 3
    nameLbl.Parent             = card

    local hasId = hd.id ~= nil
    local idLbl = Instance.new("TextLabel")
    idLbl.Size               = UDim2.new(1, -50, 0, 12)
    idLbl.Position           = UDim2.new(0, 47, 0, 21)
    idLbl.BackgroundTransparency = 1
    idLbl.Text               = hasId and ("ID:"..tostring(hd.id):sub(1,9)) or "No ID"
    idLbl.TextColor3         = hasId and Color3.fromRGB(50,195,80) or Color3.fromRGB(200,55,55)
    idLbl.TextSize           = 8
    idLbl.Font               = Enum.Font.Gotham
    idLbl.TextXAlignment     = Enum.TextXAlignment.Left
    idLbl.ZIndex             = 3
    idLbl.Parent             = card

    cardMap[card] = hd

    card.MouseButton1Click:Connect(function()
        deselectAll()
        selectedHair = hd
        card.BackgroundColor3 = Color3.fromRGB(22,12,38)
        cs.Color = Color3.fromRGB(180, 60, 255); cs.Thickness = 1.5
        setStatus("✦ "..hd.name, Color3.fromRGB(170,60,255))
    end)
end

local function populateGrid()
    for c in pairs(cardMap) do c:Destroy() end
    cardMap = {}; selectedHair = nil
    for _, c in ipairs(scroll:GetChildren()) do
        if c:IsA("TextLabel") then c:Destroy() end
    end

    if #allHairs == 0 then
        local e = Instance.new("TextLabel")
        e.Size               = UDim2.new(1,0,0,40)
        e.BackgroundTransparency = 1
        e.Text               = "Aksesuar yok\nSaç giy + Scan"
        e.TextColor3         = Color3.fromRGB(100,100,130)
        e.TextSize           = 10
        e.Font               = Enum.Font.Gotham
        e.Parent             = scroll
        scroll.CanvasSize    = UDim2.new(0,0,0,48)
        return
    end

    for i, hd in ipairs(allHairs) do buildCard(hd, i) end
    scroll.CanvasSize = UDim2.new(0,0,0, #allHairs * 52)
end

-- ──────────────────────────────────────────────────────────
--  BUTON AKSIYONLARI
-- ──────────────────────────────────────────────────────────
scanBtn.MouseButton1Click:Connect(function()
    scanHairs(); populateGrid()
    setStatus("↺ "..#allHairs.." aksesuar", Color3.fromRGB(50,200,80))
end)

colorBtn.MouseButton1Click:Connect(function()
    if not selectedHair then setStatus("⚠ Önce seç!", Color3.fromRGB(240,150,20)); return end
    if not selectedHair.id then setStatus("✕ ID yok", Color3.fromRGB(200,50,50)); return end
    applyColor(selectedHair, Color3.fromHSV(curH, curS, curV))
    setStatus("✓ Renk uygulandı", Color3.fromRGB(50,200,80))
end)

colorAllBtn.MouseButton1Click:Connect(function()
    if #allHairs == 0 then setStatus("⚠ Scan yap!", Color3.fromRGB(240,150,20)); return end
    applyToAll(Color3.fromHSV(curH, curS, curV))
    setStatus("✓ Tümüne uygulandı ("..#allHairs..")", Color3.fromRGB(50,200,80))
end)

local RGB_ON  = Color3.fromRGB(120, 30, 210)
local RGB_OFF = Color3.fromRGB(35, 35, 50)

rgbBtn.MouseButton1Click:Connect(function()
    rgbMode = not rgbMode
    rgbBtn.Text             = rgbMode and "🌈RGB:ON"  or "🌈RGB:OFF"
    rgbBtn.BackgroundColor3 = rgbMode and RGB_ON or RGB_OFF
    setStatus(rgbMode and "🌈 RGB modu aktif!" or "RGB kapatıldı",
              rgbMode and Color3.fromRGB(180,70,255) or nil)
end)

closeBtn.MouseButton1Click:Connect(function() sg:Destroy() end)

local minimized = false
minBtn.MouseButton1Click:Connect(function()
    minimized = not minimized
    TweenService:Create(main, TweenInfo.new(0.15,Enum.EasingStyle.Quad), {
        Size = minimized and UDim2.new(0,W,0,BAR) or UDim2.new(0,W,0,H)
    }):Play()
    task.delay(minimized and 0 or 0.15, function()
        content.Visible = not minimized
    end)
end)

-- ──────────────────────────────────────────────────────────
--  HEARTBEAT
-- ──────────────────────────────────────────────────────────
RunService.Heartbeat:Connect(function(dt)
    if rgbMode then
        rgbHue = (rgbHue + dt * 0.4) % 1
        curH   = rgbHue
        curS   = 1; curV = 1
        refreshColor()
        local now = tick()
        if now - lastApply >= 0.22 and #allHairs > 0 then
            lastApply = now
            applyToAll(Color3.fromHSV(curH, curS, curV))
        end
        mainStroke.Color = Color3.fromHSV(rgbHue, 1, 1)
    else
        mainStroke.Color = Color3.fromRGB(140, 45, 230)
    end
end)

-- ──────────────────────────────────────────────────────────
--  BAŞLAT
-- ──────────────────────────────────────────────────────────
refreshColor()
scanHairs()
populateGrid()
setStatus(#allHairs > 0 and (#allHairs.." aksesuar") or "Scan → Seç → Renklendir")
