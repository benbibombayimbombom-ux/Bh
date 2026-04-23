-- ============================================================
--  BROOKHAVEN HAIR COLOR ADJUSTER
--  LocalScript → StarterPlayerScripts veya executor'a yapıştır
-- ============================================================

local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService  = game:GetService("UserInputService")
local TweenService      = game:GetService("TweenService")

local player    = Players.LocalPlayer
local playerGui = player.PlayerGui

-- Remotes
local Remotes           = ReplicatedStorage:WaitForChild("Remotes")
local SetAccessoryColor = Remotes:WaitForChild("SetAccessoryColor")

-- ──────────────────────────────────────────────────────────
--  STATE
-- ──────────────────────────────────────────────────────────
local allHairs    = {}
local selectedHair = nil
local colorR, colorG, colorB = 1, 0.3, 0.8
local rgbMode     = false
local rgbHue      = 0
local lastApply   = 0

-- ──────────────────────────────────────────────────────────
--  UTILITIES
-- ──────────────────────────────────────────────────────────

-- Accessory'nin asset ID'sini bulmaya çalışır (çeşitli yollarla)
local function getAssetId(acc)
    -- 1) Attribute kontrolü
    local id = acc:GetAttribute("AssetId") or acc:GetAttribute("assetId")
    if id then return id end

    local h = acc:FindFirstChild("Handle")
    if not h then return nil end

    id = h:GetAttribute("AssetId") or h:GetAttribute("assetId")
    if id then return id end

    -- 2) SpecialMesh'ten mesh ID'yi çek
    local sm = h:FindFirstChildOfClass("SpecialMesh")
    if sm and sm.MeshId and sm.MeshId ~= "" then
        local num = sm.MeshId:match("%d+")
        if num then return tonumber(num) end
    end

    -- 3) MeshPart ise
    if h:IsA("MeshPart") and h.MeshId ~= "" then
        local num = h.MeshId:match("%d+")
        if num then return tonumber(num) end
    end

    return nil
end

local function applyColor(hairData, r, g, b)
    if not hairData or not hairData.id then return end
    pcall(function()
        SetAccessoryColor:InvokeServer(hairData.id, {
            color = { r = r, g = g, b = b }
        })
    end)
end

local function applyToAll(r, g, b)
    for _, hd in ipairs(allHairs) do
        applyColor(hd, r, g, b)
    end
end

local function scanHairs()
    allHairs = {}
    selectedHair = nil
    local char = player.Character
    if not char then return end
    for _, c in ipairs(char:GetChildren()) do
        if c:IsA("Accessory") then
            table.insert(allHairs, {
                accessory = c,
                id        = getAssetId(c),
                name      = c.Name,
            })
        end
    end
end

-- ──────────────────────────────────────────────────────────
--  REMOVE OLD GUI
-- ──────────────────────────────────────────────────────────
if playerGui:FindFirstChild("HCA_GUI") then
    playerGui.HCA_GUI:Destroy()
end

-- ──────────────────────────────────────────────────────────
--  SCREEN GUI
-- ──────────────────────────────────────────────────────────
local sg = Instance.new("ScreenGui")
sg.Name            = "HCA_GUI"
sg.ResetOnSpawn    = false
sg.ZIndexBehavior  = Enum.ZIndexBehavior.Sibling
sg.IgnoreGuiInset  = true
sg.Parent          = playerGui

-- ──────────────────────────────────────────────────────────
--  MAIN FRAME
-- ──────────────────────────────────────────────────────────
local W, H   = 340, 522
local TITLE_H = 46

local main = Instance.new("Frame")
main.Name             = "Main"
main.Size             = UDim2.new(0, W, 0, H)
main.Position         = UDim2.new(0.5, -W/2, 0.5, -H/2)
main.BackgroundColor3 = Color3.fromRGB(11, 11, 17)
main.BorderSizePixel  = 0
main.ClipsDescendants = true
main.Parent           = sg
Instance.new("UICorner", main).CornerRadius = UDim.new(0, 14)

-- Glow border (mor)
local mainStroke = Instance.new("UIStroke")
mainStroke.Color      = Color3.fromRGB(160, 50, 255)
mainStroke.Thickness  = 1.5
mainStroke.Transparency = 0.2
mainStroke.Parent     = main

-- ──────────────────────────────────────────────────────────
--  TITLE BAR
-- ──────────────────────────────────────────────────────────
local bar = Instance.new("Frame")
bar.Size             = UDim2.new(1, 0, 0, TITLE_H)
bar.BackgroundColor3 = Color3.fromRGB(17, 17, 26)
bar.BorderSizePixel  = 0
bar.ZIndex           = 5
bar.Parent           = main

do  -- Gradient across title bar
    local g = Instance.new("UIGradient")
    g.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(70, 20, 120)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(17, 17, 26)),
    })
    g.Rotation = 90
    g.Parent = bar
end

local titleIcon = Instance.new("TextLabel")
titleIcon.Size               = UDim2.new(0, 28, 1, 0)
titleIcon.Position           = UDim2.new(0, 12, 0, 0)
titleIcon.BackgroundTransparency = 1
titleIcon.Text               = "✦"
titleIcon.TextColor3         = Color3.fromRGB(210, 90, 255)
titleIcon.TextSize           = 20
titleIcon.Font               = Enum.Font.GothamBold
titleIcon.ZIndex             = 6
titleIcon.Parent             = bar

local titleLbl = Instance.new("TextLabel")
titleLbl.Size               = UDim2.new(1, -110, 1, 0)
titleLbl.Position           = UDim2.new(0, 42, 0, 0)
titleLbl.BackgroundTransparency = 1
titleLbl.Text               = "Hair Color Adjuster"
titleLbl.TextColor3         = Color3.fromRGB(235, 235, 255)
titleLbl.TextSize           = 15
titleLbl.Font               = Enum.Font.GothamBold
titleLbl.TextXAlignment     = Enum.TextXAlignment.Left
titleLbl.ZIndex             = 6
titleLbl.Parent             = bar

-- Küçük yardımcı: başlık butonları
local function mkTitleBtn(icon, col, xOff)
    local b = Instance.new("TextButton")
    b.Size             = UDim2.new(0, 26, 0, 26)
    b.Position         = UDim2.new(1, xOff, 0.5, -13)
    b.BackgroundColor3 = col
    b.Text             = icon
    b.TextColor3       = Color3.fromRGB(255, 255, 255)
    b.TextSize         = 13
    b.Font             = Enum.Font.GothamBold
    b.BorderSizePixel  = 0
    b.ZIndex           = 6
    b.Parent           = bar
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
    return b
end

local minBtn   = mkTitleBtn("−", Color3.fromRGB(220, 150, 25), -60)
local closeBtn = mkTitleBtn("✕", Color3.fromRGB(205, 50, 50),  -30)

-- ── Drag (mobil + pc) ─────────────────────
local dragging   = false
local dragStart  = nil
local dragOrigin = nil

bar.InputBegan:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1 or
       i.UserInputType == Enum.UserInputType.Touch then
        dragging   = true
        dragStart  = i.Position
        dragOrigin = main.Position
        i.Changed:Connect(function()
            if i.UserInputState == Enum.UserInputState.End then
                dragging = false
            end
        end)
    end
end)

UserInputService.InputChanged:Connect(function(i)
    if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or
                     i.UserInputType == Enum.UserInputType.Touch) then
        local d = i.Position - dragStart
        main.Position = UDim2.new(
            dragOrigin.X.Scale, dragOrigin.X.Offset + d.X,
            dragOrigin.Y.Scale, dragOrigin.Y.Offset + d.Y
        )
    end
end)

-- ──────────────────────────────────────────────────────────
--  CONTENT AREA
-- ──────────────────────────────────────────────────────────
local content = Instance.new("Frame")
content.Size             = UDim2.new(1, 0, 1, -TITLE_H)
content.Position         = UDim2.new(0, 0, 0, TITLE_H)
content.BackgroundTransparency = 1
content.ClipsDescendants = false
content.Parent           = main

-- Küçük yardımcı: bölüm başlığı
local function mkSectionLbl(text, yOff)
    local l = Instance.new("TextLabel")
    l.Size               = UDim2.new(1, -12, 0, 20)
    l.Position           = UDim2.new(0, 8, 0, yOff)
    l.BackgroundTransparency = 1
    l.Text               = text
    l.TextColor3         = Color3.fromRGB(170, 80, 255)
    l.TextSize           = 10
    l.Font               = Enum.Font.GothamBold
    l.TextXAlignment     = Enum.TextXAlignment.Left
    l.Parent             = content
    return l
end

-- ── BÖLÜM 1: Accessory Listesi ─────────────
mkSectionLbl("✦  ACCESSORIES", 7)

local scanBtn = Instance.new("TextButton")
scanBtn.Size             = UDim2.new(0, 64, 0, 18)
scanBtn.Position         = UDim2.new(1, -72, 0, 8)
scanBtn.BackgroundColor3 = Color3.fromRGB(20, 65, 36)
scanBtn.Text             = "↺  Scan"
scanBtn.TextColor3       = Color3.fromRGB(65, 205, 95)
scanBtn.TextSize         = 10
scanBtn.Font             = Enum.Font.GothamBold
scanBtn.BorderSizePixel  = 0
scanBtn.Parent           = content
Instance.new("UICorner", scanBtn).CornerRadius = UDim.new(0, 4)

local scroll = Instance.new("ScrollingFrame")
scroll.Size                  = UDim2.new(1, -12, 0, 188)
scroll.Position              = UDim2.new(0, 6, 0, 30)
scroll.BackgroundColor3      = Color3.fromRGB(15, 15, 22)
scroll.BorderSizePixel       = 0
scroll.ScrollBarThickness    = 3
scroll.ScrollBarImageColor3  = Color3.fromRGB(160, 80, 255)
scroll.CanvasSize            = UDim2.new(0, 0, 0, 0)
scroll.ScrollingDirection    = Enum.ScrollingDirection.Y
scroll.Parent                = content
Instance.new("UICorner", scroll).CornerRadius = UDim.new(0, 8)

local gridLayout = Instance.new("UIGridLayout")
gridLayout.CellSize            = UDim2.new(0, 88, 0, 100)
gridLayout.CellPadding         = UDim2.new(0, 5, 0, 5)
gridLayout.SortOrder           = Enum.SortOrder.LayoutOrder
gridLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
gridLayout.Parent              = scroll

local gridPad = Instance.new("UIPadding")
gridPad.PaddingTop = UDim.new(0, 5)
gridPad.Parent     = scroll

-- ── Ayırıcı ──────────────────────────────
local divider = Instance.new("Frame")
divider.Size             = UDim2.new(1, -20, 0, 1)
divider.Position         = UDim2.new(0, 10, 0, 224)
divider.BackgroundColor3 = Color3.fromRGB(55, 25, 90)
divider.BorderSizePixel  = 0
divider.Parent           = content

-- ── BÖLÜM 2: Renk Seçici ─────────────────
mkSectionLbl("✦  COLOR PICKER", 230)

-- Renk önizleme çubuğu
local preview = Instance.new("Frame")
preview.Size             = UDim2.new(1, -12, 0, 20)
preview.Position         = UDim2.new(0, 6, 0, 253)
preview.BackgroundColor3 = Color3.new(colorR, colorG, colorB)
preview.BorderSizePixel  = 0
preview.Parent           = content
Instance.new("UICorner", preview).CornerRadius = UDim.new(0, 5)

-- Hex değeri etiketi
local hexLbl = Instance.new("TextLabel")
hexLbl.Size               = UDim2.new(1, 0, 1, 0)
hexLbl.BackgroundTransparency = 1
hexLbl.Text               = "#FF4DCC"
hexLbl.TextColor3         = Color3.fromRGB(255, 255, 255)
hexLbl.TextSize           = 9
hexLbl.Font               = Enum.Font.GothamBold
hexLbl.TextXAlignment     = Enum.TextXAlignment.Right
hexLbl.ZIndex             = 2
hexLbl.Parent             = preview

local hexPad = Instance.new("UIPadding")
hexPad.PaddingRight = UDim.new(0, 6)
hexPad.Parent = hexLbl

local function toHex(r, g, b)
    return string.format("#%02X%02X%02X",
        math.floor(r*255),
        math.floor(g*255),
        math.floor(b*255))
end

-- ── Slider yardımcısı ─────────────────────
local function mkSlider(label, col, yOff, initVal, onChanged)
    local row = Instance.new("Frame")
    row.Size             = UDim2.new(1, -12, 0, 28)
    row.Position         = UDim2.new(0, 6, 0, yOff)
    row.BackgroundTransparency = 1
    row.Parent           = content

    local lbl = Instance.new("TextLabel")
    lbl.Size             = UDim2.new(0, 14, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text             = label
    lbl.TextColor3       = col
    lbl.TextSize         = 11
    lbl.Font             = Enum.Font.GothamBold
    lbl.Parent           = row

    local track = Instance.new("Frame")
    track.Size             = UDim2.new(1, -52, 0, 5)
    track.Position         = UDim2.new(0, 18, 0.5, -2)
    track.BackgroundColor3 = Color3.fromRGB(32, 32, 48)
    track.BorderSizePixel  = 0
    track.Parent           = row
    Instance.new("UICorner", track).CornerRadius = UDim.new(0, 3)

    local fill = Instance.new("Frame")
    fill.Size             = UDim2.new(initVal, 0, 1, 0)
    fill.BackgroundColor3 = col
    fill.BorderSizePixel  = 0
    fill.Parent           = track
    Instance.new("UICorner", fill).CornerRadius = UDim.new(0, 3)

    local thumb = Instance.new("Frame")
    thumb.Size             = UDim2.new(0, 14, 0, 14)
    thumb.AnchorPoint      = Vector2.new(0.5, 0.5)
    thumb.Position         = UDim2.new(initVal, 0, 0.5, 0)
    thumb.BackgroundColor3 = Color3.fromRGB(240, 240, 255)
    thumb.BorderSizePixel  = 0
    thumb.ZIndex           = 2
    thumb.Parent           = track
    Instance.new("UICorner", thumb).CornerRadius = UDim.new(1, 0)

    local valLbl = Instance.new("TextLabel")
    valLbl.Size               = UDim2.new(0, 30, 1, 0)
    valLbl.Position           = UDim2.new(1, -30, 0, 0)
    valLbl.BackgroundTransparency = 1
    valLbl.Text               = tostring(math.floor(initVal * 255))
    valLbl.TextColor3         = Color3.fromRGB(165, 165, 195)
    valLbl.TextSize           = 10
    valLbl.Font               = Enum.Font.Gotham
    valLbl.TextXAlignment     = Enum.TextXAlignment.Right
    valLbl.Parent             = row

    local val = initVal

    -- Sadece görsel güncelle (callback yok) — RGB modu için
    local function setVisual(v)
        val = math.clamp(v, 0, 1)
        fill.Size       = UDim2.new(val, 0, 1, 0)
        thumb.Position  = UDim2.new(val, 0, 0.5, 0)
        valLbl.Text     = tostring(math.floor(val * 255))
    end

    -- Görsel + callback
    local function set(v)
        setVisual(v)
        onChanged(val)
    end

    local slDrag = false

    local function onInput(i)
        local rel = (i.Position.X - track.AbsolutePosition.X) / track.AbsoluteSize.X
        set(rel)
    end

    track.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or
           i.UserInputType == Enum.UserInputType.Touch then
            slDrag = true
            onInput(i)
        end
    end)

    UserInputService.InputChanged:Connect(function(i)
        if slDrag and (i.UserInputType == Enum.UserInputType.MouseMovement or
                       i.UserInputType == Enum.UserInputType.Touch) then
            onInput(i)
        end
    end)

    UserInputService.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or
           i.UserInputType == Enum.UserInputType.Touch then
            slDrag = false
        end
    end)

    setVisual(initVal)
    return { set = set, setVisual = setVisual, get = function() return val end }
end

local rSl = mkSlider("R", Color3.fromRGB(255, 70,  70),  279, colorR, function(v) colorR = v end)
local gSl = mkSlider("G", Color3.fromRGB(55,  210, 55),  309, colorG, function(v) colorG = v end)
local bSl = mkSlider("B", Color3.fromRGB(60,  130, 255), 339, colorB, function(v) colorB = v end)

-- ── Aksiyon Butonları ─────────────────────
local btnArea = Instance.new("Frame")
btnArea.Size             = UDim2.new(1, -12, 0, 36)
btnArea.Position         = UDim2.new(0, 6, 0, 376)
btnArea.BackgroundTransparency = 1
btnArea.Parent           = content

local btnListLay = Instance.new("UIListLayout")
btnListLay.FillDirection        = Enum.FillDirection.Horizontal
btnListLay.Padding              = UDim.new(0, 5)
btnListLay.SortOrder            = Enum.SortOrder.LayoutOrder
btnListLay.HorizontalAlignment  = Enum.HorizontalAlignment.Center
btnListLay.VerticalAlignment    = Enum.VerticalAlignment.Center
btnListLay.Parent               = btnArea

local function mkBtn(text, bg, order)
    local b = Instance.new("TextButton")
    b.Size             = UDim2.new(0, 96, 1, 0)
    b.BackgroundColor3 = bg
    b.Text             = text
    b.TextColor3       = Color3.fromRGB(255, 255, 255)
    b.TextSize         = 11
    b.Font             = Enum.Font.GothamBold
    b.BorderSizePixel  = 0
    b.LayoutOrder      = order
    b.AutoButtonColor  = false
    b.Parent           = btnArea
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 8)
    -- Hover efekti
    b.MouseEnter:Connect(function()
        TweenService:Create(b, TweenInfo.new(0.12), {
            BackgroundColor3 = bg:lerp(Color3.fromRGB(255,255,255), 0.12)
        }):Play()
    end)
    b.MouseLeave:Connect(function()
        TweenService:Create(b, TweenInfo.new(0.12), {BackgroundColor3 = bg}):Play()
    end)
    return b
end

local colorBtn    = mkBtn("🎨 Color",     Color3.fromRGB(40,  90, 210), 1)
local colorAllBtn = mkBtn("✦ Color All", Color3.fromRGB(100, 40, 190), 2)
local rgbBtn      = mkBtn("🌈 RGB: OFF", Color3.fromRGB(38,  38,  55), 3)

-- ── Durum çubuğu ──────────────────────────
local statusBar = Instance.new("Frame")
statusBar.Size             = UDim2.new(1, -12, 0, 28)
statusBar.Position         = UDim2.new(0, 6, 0, 420)
statusBar.BackgroundColor3 = Color3.fromRGB(16, 16, 24)
statusBar.BorderSizePixel  = 0
statusBar.Parent           = content
Instance.new("UICorner", statusBar).CornerRadius = UDim.new(0, 6)

local statusTxt = Instance.new("TextLabel")
statusTxt.Size               = UDim2.new(1, -10, 1, 0)
statusTxt.Position           = UDim2.new(0, 8, 0, 0)
statusTxt.BackgroundTransparency = 1
statusTxt.Text               = "Scan accessories to get started"
statusTxt.TextColor3         = Color3.fromRGB(130, 130, 165)
statusTxt.TextSize           = 11
statusTxt.Font               = Enum.Font.Gotham
statusTxt.TextXAlignment     = Enum.TextXAlignment.Left
statusTxt.TextTruncate       = Enum.TextTruncate.AtEnd
statusTxt.Parent             = statusBar

local function setStatus(msg, col)
    statusTxt.Text      = msg
    statusTxt.TextColor3 = col or Color3.fromRGB(130, 130, 165)
end

-- ──────────────────────────────────────────────────────────
--  KART OLUŞTURUCU (ViewportFrame)
-- ──────────────────────────────────────────────────────────
local cardMap = {}  -- TextButton → hairData

local function deselectAll()
    for card in pairs(cardMap) do
        local sel = card:FindFirstChild("__sel")
        if sel then sel.Visible = false end
        local str = card:FindFirstChildOfClass("UIStroke")
        if str then
            str.Color     = Color3.fromRGB(40, 40, 62)
            str.Thickness = 1
        end
    end
end

local function buildCard(hd, idx)
    local card = Instance.new("TextButton")
    card.Name             = "Card_" .. idx
    card.Size             = UDim2.new(0, 88, 0, 100)
    card.BackgroundColor3 = Color3.fromRGB(18, 18, 28)
    card.BorderSizePixel  = 0
    card.Text             = ""
    card.LayoutOrder      = idx
    card.AutoButtonColor  = false
    card.Parent           = scroll
    Instance.new("UICorner", card).CornerRadius = UDim.new(0, 8)

    local cardStroke = Instance.new("UIStroke")
    cardStroke.Color      = Color3.fromRGB(40, 40, 62)
    cardStroke.Thickness  = 1
    cardStroke.Parent     = card

    -- Seçili overlay
    local selFrame = Instance.new("Frame")
    selFrame.Name             = "__sel"
    selFrame.Size             = UDim2.new(1, 0, 1, 0)
    selFrame.BackgroundColor3 = Color3.fromRGB(160, 50, 255)
    selFrame.BackgroundTransparency = 0.82
    selFrame.BorderSizePixel  = 0
    selFrame.Visible          = false
    selFrame.ZIndex           = 4
    selFrame.Parent           = card
    Instance.new("UICorner", selFrame).CornerRadius = UDim.new(0, 8)

    local selStroke = Instance.new("UIStroke")
    selStroke.Color      = Color3.fromRGB(200, 80, 255)
    selStroke.Thickness  = 2
    selStroke.Parent     = selFrame

    -- ViewportFrame
    local vp = Instance.new("ViewportFrame")
    vp.Size             = UDim2.new(1, 0, 0, 72)
    vp.BackgroundColor3 = Color3.fromRGB(12, 12, 18)
    vp.BorderSizePixel  = 0
    vp.ZIndex           = 2
    vp.Parent           = card
    Instance.new("UICorner", vp).CornerRadius = UDim.new(0, 8)

    -- Accessory klonu
    local clone = hd.accessory:Clone()
    local handle = clone:FindFirstChild("Handle")
    if handle then
        handle.CFrame = CFrame.new(0, 0, 0)
        if handle:IsA("BasePart") then handle.Anchored = true end
        for _, w in ipairs(handle:GetChildren()) do
            if w:IsA("Weld") or w:IsA("WeldConstraint") or w:IsA("Motor6D") then
                w:Destroy()
            end
        end
    end
    clone.Parent = vp

    local cam = Instance.new("Camera")
    cam.FieldOfView = 45
    cam.CFrame      = CFrame.new(Vector3.new(0, 0.4, 2.4), Vector3.new(0, 0.4, 0))
    cam.Parent      = vp
    vp.CurrentCamera = cam

    -- İsim etiketi
    local nameLbl = Instance.new("TextLabel")
    nameLbl.Size               = UDim2.new(1, -4, 0, 16)
    nameLbl.Position           = UDim2.new(0, 2, 0, 74)
    nameLbl.BackgroundTransparency = 1
    nameLbl.Text               = hd.name
    nameLbl.TextColor3         = Color3.fromRGB(200, 200, 220)
    nameLbl.TextSize           = 9
    nameLbl.Font               = Enum.Font.Gotham
    nameLbl.TextTruncate       = Enum.TextTruncate.AtEnd
    nameLbl.TextXAlignment     = Enum.TextXAlignment.Center
    nameLbl.ZIndex             = 3
    nameLbl.Parent             = card

    -- ID rozeti
    local hasId = hd.id ~= nil
    local idLbl = Instance.new("TextLabel")
    idLbl.Size               = UDim2.new(1, -4, 0, 12)
    idLbl.Position           = UDim2.new(0, 2, 0, 87)
    idLbl.BackgroundTransparency = 1
    idLbl.Text               = hasId and ("✓ " .. tostring(hd.id):sub(1, 9)) or "✕ No ID"
    idLbl.TextColor3         = hasId and Color3.fromRGB(55, 195, 90) or Color3.fromRGB(205, 65, 65)
    idLbl.TextSize           = 8
    idLbl.Font               = Enum.Font.Gotham
    idLbl.TextXAlignment     = Enum.TextXAlignment.Center
    idLbl.ZIndex             = 3
    idLbl.Parent             = card

    cardMap[card] = hd

    card.MouseButton1Click:Connect(function()
        deselectAll()
        selectedHair     = hd
        selFrame.Visible = true
        cardStroke.Color     = Color3.fromRGB(200, 80, 255)
        cardStroke.Thickness = 2
        setStatus("✦ Seçildi: " .. hd.name, Color3.fromRGB(190, 80, 255))
    end)

    return card
end

-- ──────────────────────────────────────────────────────────
--  GRID DOLDUR
-- ──────────────────────────────────────────────────────────
local function populateGrid()
    for c in pairs(cardMap) do c:Destroy() end
    cardMap = {}
    selectedHair = nil
    -- Boş etiket kalıntılarını da temizle
    for _, c in ipairs(scroll:GetChildren()) do
        if c:IsA("TextLabel") then c:Destroy() end
    end

    if #allHairs == 0 then
        local empty = Instance.new("TextLabel")
        empty.Size               = UDim2.new(1, 0, 0, 60)
        empty.BackgroundTransparency = 1
        empty.Text               = "Aksesuar bulunamadı\nÖnce saç giyin!"
        empty.TextColor3         = Color3.fromRGB(120, 120, 155)
        empty.TextSize           = 12
        empty.Font               = Enum.Font.Gotham
        empty.Parent             = scroll
        scroll.CanvasSize = UDim2.new(0, 0, 0, 70)
        return
    end

    for i, hd in ipairs(allHairs) do
        buildCard(hd, i)
    end

    local rows = math.ceil(#allHairs / 3)
    scroll.CanvasSize = UDim2.new(0, 0, 0, rows * 105 + 10)
end

-- ──────────────────────────────────────────────────────────
--  BUTON AKSIYONLARI
-- ──────────────────────────────────────────────────────────

scanBtn.MouseButton1Click:Connect(function()
    scanHairs()
    populateGrid()
    local n = #allHairs
    setStatus("↺ " .. n .. " aksesuar bulundu",
              Color3.fromRGB(55, 200, 90))
end)

colorBtn.MouseButton1Click:Connect(function()
    if not selectedHair then
        setStatus("⚠ Önce bir aksesuar seç!", Color3.fromRGB(250, 155, 25))
        return
    end
    if not selectedHair.id then
        setStatus("✕ Bu aksesuarın ID'si algılanamadı", Color3.fromRGB(205, 60, 60))
        return
    end
    applyColor(selectedHair, colorR, colorG, colorB)
    setStatus("✓ Renk uygulandı: " .. selectedHair.name, Color3.fromRGB(55, 200, 90))
end)

colorAllBtn.MouseButton1Click:Connect(function()
    if #allHairs == 0 then
        setStatus("⚠ Önce scan yap!", Color3.fromRGB(250, 155, 25))
        return
    end
    applyToAll(colorR, colorG, colorB)
    setStatus("✓ Tüm " .. #allHairs .. " aksesuara renk uygulandı", Color3.fromRGB(55, 200, 90))
end)

local RGB_BG_ON  = Color3.fromRGB(140, 35, 220)
local RGB_BG_OFF = Color3.fromRGB(38, 38, 55)

rgbBtn.MouseButton1Click:Connect(function()
    rgbMode = not rgbMode
    if rgbMode then
        rgbBtn.Text             = "🌈 RGB: ON"
        rgbBtn.BackgroundColor3 = RGB_BG_ON
        setStatus("🌈 RGB gökkuşağı modu aktif!", Color3.fromRGB(180, 75, 255))
    else
        rgbBtn.Text             = "🌈 RGB: OFF"
        rgbBtn.BackgroundColor3 = RGB_BG_OFF
        setStatus("RGB modu kapatıldı", Color3.fromRGB(130, 130, 165))
    end
end)

closeBtn.MouseButton1Click:Connect(function()
    sg:Destroy()
end)

local minimized = false
minBtn.MouseButton1Click:Connect(function()
    minimized = not minimized
    TweenService:Create(main, TweenInfo.new(0.18, Enum.EasingStyle.Quad), {
        Size = minimized and UDim2.new(0, W, 0, TITLE_H) or UDim2.new(0, W, 0, H)
    }):Play()
    task.delay(minimized and 0 or 0.18, function()
        content.Visible = not minimized
    end)
end)

-- ──────────────────────────────────────────────────────────
--  HEARTBEAT — RGB döngüsü + önizleme güncellemesi
-- ──────────────────────────────────────────────────────────
RunService.Heartbeat:Connect(function(dt)
    if rgbMode then
        -- Hue ilerlet
        rgbHue = (rgbHue + dt * 0.38) % 1
        local c = Color3.fromHSV(rgbHue, 1, 1)
        colorR, colorG, colorB = c.R, c.G, c.B

        -- Slider görsellerini güncelle (callback tetiklemeden)
        rSl.setVisual(colorR)
        gSl.setVisual(colorG)
        bSl.setVisual(colorB)

        -- Border rengi de gökkuşağı olsun
        mainStroke.Color = c

        -- Throttle: her 0.22 sn'de bir sunucuya gönder
        local now = tick()
        if now - lastApply >= 0.22 and #allHairs > 0 then
            lastApply = now
            applyToAll(colorR, colorG, colorB)
        end
    else
        mainStroke.Color = Color3.fromRGB(160, 50, 255)
    end

    -- Önizleme + hex güncelle
    local col = Color3.new(colorR, colorG, colorB)
    preview.BackgroundColor3 = col
    hexLbl.Text = toHex(colorR, colorG, colorB)
end)

-- ──────────────────────────────────────────────────────────
--  BAŞLATMA
-- ──────────────────────────────────────────────────────────
scanHairs()
populateGrid()
setStatus(
    #allHairs > 0
    and ("↺ " .. #allHairs .. " aksesuar — birine tıkla")
    or  "Scan yap → Aksesuar yükle",
    Color3.fromRGB(130, 130, 165)
)
