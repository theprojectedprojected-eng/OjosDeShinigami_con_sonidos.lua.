-- ═══════════════════════════════════════════════════════════════════
--  OJOS DE SHINIGAMI 🔴  ·  versión animada
--  LocalScript → StarterPlayer > StarterPlayerScripts
--  Todo lo que puedes tocar está en CONFIG (justo aquí abajo).
-- ═══════════════════════════════════════════════════════════════════

local Players          = game:GetService("Players")
local Lighting         = game:GetService("Lighting")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local SoundService     = game:GetService("SoundService")
local TextService      = game:GetService("TextService")
local Debris           = game:GetService("Debris")

local localPlayer = Players.LocalPlayer
local playerGui   = localPlayer:WaitForChild("PlayerGui")

-- ⚙️ CONFIGURACIÓN ─────────────────────────────────────────────────
local CONFIG = {
    -- Control
    tecla         = Enum.KeyCode.K,
    botonMovil    = true,    -- botón "OJOS" en pantalla (solo celular/tablet)
    empezarActivo = true,

    -- Qué se muestra sobre cada jugador
    usarNombreReal   = false, -- true = usuario real en vez del nombre visible
    mostrarId        = true,
    mostrarVida      = true,
    mostrarBarraVida = true,

    -- Alcance
    distanciaMaxima   = 150, -- studs; más lejos no se ve nada
    inicioDesvanecido = 0.5, -- fracción de esa distancia donde empieza a desvanecerse
    escalaLejos       = 0.6, -- tamaño de la etiqueta en el límite (1 = no se achica)

    -- Nombre
    amplitudLetras = 4,      -- píxeles que sube/baja cada letra
    giroLetras     = 3,      -- grados de balanceo de cada letra
    titileoLetras  = true,   -- de vez en cuando una letra parpadea
    duracionReveal = 0.8,    -- segundos que tarda en aparecer el nombre

    -- Sobre el personaje
    resplandor          = true,
    hitbox              = true,
    hitboxModo          = "cuerpo", -- "cuerpo" = cada parte · "raiz" = solo HumanoidRootPart
    hitboxTransparencia = 0.6,      -- más alto = más transparente

    -- Pantalla (todo muy sutil)
    tinte            = true,
    tinteColor       = Color3.fromRGB(255, 249, 249),
    vineta           = true,
    vinetaIntensidad = 0.35,
    parpadeo         = true, -- parpadeo de los ojos al encender/apagar
    desenfoque       = 6,    -- 0 = sin desenfoque durante el parpadeo
    aviso            = true, -- cartel "OJOS DE SHINIGAMI" al cambiar

    -- Sonidos (opcional): pega tu ID, por ejemplo "rbxassetid://123456"
    sonidoEncender = "rbxassetid://127184789689744",
    sonidoApagar   = "rbxassetid://81638346248225",
    volumen        = 0.5,
}

-- ── Colores y fuente ─────────────────────────────────────────────
local ROJO        = Color3.fromRGB(255, 35, 35)
local ROJO_VIVO   = Color3.fromRGB(255, 95, 95)
local ROJO_OSCURO = Color3.fromRGB(110, 0, 0)
local ROSA        = Color3.fromRGB(255, 195, 195)
local GRIS        = Color3.fromRGB(125, 125, 125)
local BLANCO      = Color3.new(1, 1, 1)
local FUENTE      = Enum.Font.Merriweather

-- ── Utilidades ───────────────────────────────────────────────────
local function clamp01(x)
    return math.clamp(x, 0, 1)
end

local function lerp(a, b, t)
    return a + (b - a) * t
end

local function suave(x)
    x = clamp01(x)
    return x * x * (3 - 2 * x)
end

local function entero(n)
    if n ~= n then return 0 end
    return math.floor(math.clamp(n, 0, 1e9))
end

local function rgbTag(c)
    return string.format("rgb(%d,%d,%d)",
        math.floor(c.R * 255 + 0.5),
        math.floor(c.G * 255 + 0.5),
        math.floor(c.B * 255 + 0.5))
end

-- Crea una instancia, aplica las propiedades y al final la mete en su padre
local function crear(clase, props, padre)
    local obj = Instance.new(clase)
    for k, v in pairs(props) do
        obj[k] = v
    end
    obj.Parent = padre
    return obj
end

-- ── Estado ───────────────────────────────────────────────────────
local activo         = false
local tToggle        = -100 -- momento del último encendido/apagado
local gAlpha         = 0    -- 0..1: visibilidad global (sube y baja suave)
local nombresOcultos = false
local todoOculto     = true
local objetivos      = {}   -- [player] = datos de su etiqueta y efectos
local conexiones     = {}   -- [player] = { conexiones de eventos }
local creando        = {}   -- [player] = personaje que se está procesando

-- ── Limpieza de versiones anteriores ─────────────────────────────
for _, nombre in ipairs({ "VisionShinigami", "VisionShinigamiBlur" }) do
    local viejo = Lighting:FindFirstChild(nombre)
    if viejo then viejo:Destroy() end
end
local viejaUI = playerGui:FindFirstChild("OjosShinigamiUI")
if viejaUI then viejaUI:Destroy() end

-- ── Efectos de pantalla ──────────────────────────────────────────
local correccion = crear("ColorCorrectionEffect", { Name = "VisionShinigami" }, Lighting)
local desenfoque = crear("BlurEffect", { Name = "VisionShinigamiBlur", Size = 0 }, Lighting)

local ui = crear("ScreenGui", {
    Name = "OjosShinigamiUI",
    ResetOnSpawn = false,
    IgnoreGuiInset = true,
    DisplayOrder = 50,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, playerGui)

-- Viñeta: cuatro bordes con degradado hacia adentro
local bordes = {}
if CONFIG.vineta then
    local lados = {
        { ancla = Vector2.new(0, 0), pos = UDim2.fromScale(0, 0), tam = UDim2.fromScale(1, 0.3), rot = 90 },  -- arriba
        { ancla = Vector2.new(0, 1), pos = UDim2.fromScale(0, 1), tam = UDim2.fromScale(1, 0.3), rot = 270 }, -- abajo
        { ancla = Vector2.new(0, 0), pos = UDim2.fromScale(0, 0), tam = UDim2.fromScale(0.2, 1), rot = 0 },   -- izquierda
        { ancla = Vector2.new(1, 0), pos = UDim2.fromScale(1, 0), tam = UDim2.fromScale(0.2, 1), rot = 180 }, -- derecha
    }
    for _, lado in ipairs(lados) do
        local f = crear("Frame", {
            AnchorPoint = lado.ancla,
            Position = lado.pos,
            Size = lado.tam,
            BackgroundColor3 = Color3.fromRGB(110, 0, 0),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
        }, ui)
        crear("UIGradient", {
            Rotation = lado.rot,
            Transparency = NumberSequence.new({
                NumberSequenceKeypoint.new(0, 0.35),
                NumberSequenceKeypoint.new(1, 1),
            }),
        }, f)
        table.insert(bordes, f)
    end
end

-- Párpados: dos barras que se cierran y abren rápido
local tapas = {}
if CONFIG.parpadeo then
    for i = 1, 2 do
        tapas[i] = crear("Frame", {
            Name = (i == 1) and "TapaSuperior" or "TapaInferior",
            AnchorPoint = Vector2.new(0, (i == 1) and 0 or 1),
            Position = UDim2.fromScale(0, (i == 1) and 0 or 1),
            Size = UDim2.fromScale(1, 0),
            BackgroundColor3 = Color3.fromRGB(8, 0, 0),
            BorderSizePixel = 0,
            ZIndex = 10,
        }, ui)
    end
end

-- Cartel breve al encender/apagar
local avisoTitulo, avisoTrazoT, avisoSub, avisoTrazoS
if CONFIG.aviso then
    avisoTitulo = crear("TextLabel", {
        Name = "AvisoTitulo",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.82),
        Size = UDim2.fromOffset(420, 30),
        BackgroundTransparency = 1,
        Text = "OJOS DE SHINIGAMI",
        Font = FUENTE,
        TextSize = 24,
        TextColor3 = ROJO,
        TextTransparency = 1,
        ZIndex = 5,
    }, ui)
    avisoTrazoT = crear("UIStroke", { Color = ROJO_OSCURO, Thickness = 1.5, Transparency = 1 }, avisoTitulo)

    avisoSub = crear("TextLabel", {
        Name = "AvisoSub",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.86),
        Size = UDim2.fromOffset(420, 22),
        BackgroundTransparency = 1,
        Text = "",
        Font = FUENTE,
        TextSize = 16,
        TextColor3 = ROSA,
        TextTransparency = 1,
        ZIndex = 5,
    }, ui)
    avisoTrazoS = crear("UIStroke", { Color = Color3.new(0, 0, 0), Thickness = 1, Transparency = 1 }, avisoSub)
end

-- Botón para celular / tablet (sin teclado)
local boton
if CONFIG.botonMovil and UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
    boton = crear("TextButton", {
        Name = "BotonOjos",
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.new(0, 12, 0.4, 0),
        Size = UDim2.fromOffset(64, 40),
        BackgroundColor3 = Color3.fromRGB(40, 0, 0),
        BackgroundTransparency = 0.35,
        Text = "OJOS",
        Font = FUENTE,
        TextSize = 16,
        TextColor3 = ROJO_VIVO,
        ZIndex = 6,
    }, ui)
    crear("UICorner", { CornerRadius = UDim.new(0, 8) }, boton)
    crear("UIStroke", {
        Color = ROJO,
        Thickness = 1.2,
        Transparency = 0.3,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    }, boton)
end

-- ── Sonido ───────────────────────────────────────────────────────
local function reproducir(id)
    if id == "" then return end
    local s = Instance.new("Sound")
    s.SoundId = id
    s.Volume = CONFIG.volumen
    s.Parent = SoundService
    s:Play()
    Debris:AddItem(s, 8)
end

-- ── Ayudas de cámara / nombre ────────────────────────────────────
local function camaraPos()
    local cam = workspace.CurrentCamera
    if cam then return cam.CFrame.Position end
    return nil
end

local function distanciaA(d, camPos)
    if not camPos then return 0 end
    return (d.head.Position - camPos).Magnitude
end

local function nombreMostrado(player)
    local t = player.Name
    if not CONFIG.usarNombreReal and player.DisplayName ~= "" then
        t = player.DisplayName
    end
    if not utf8.len(t) then t = player.Name end
    return t
end

-- ── Construcción de piezas ───────────────────────────────────────
-- Una etiqueta por letra: cada una se mueve con su propio ritmo
local function crearLetras(fila, texto)
    local letras = {}
    local tam = (utf8.len(texto) > 14) and 19 or 24
    local orden = 0

    for _, codigo in utf8.codes(texto) do
        orden = orden + 1
        local ch = utf8.char(codigo)

        local ancho = tam * 0.6
        local ok, medida = pcall(function()
            return TextService:GetTextSize(ch, tam, FUENTE, Vector2.new(300, 100))
        end)
        if ok and medida then ancho = medida.X end
        if ch == " " then ancho = math.max(ancho, tam * 0.3) end

        local slot = crear("Frame", {
            Name = "Slot" .. orden,
            LayoutOrder = orden,
            Size = UDim2.fromOffset(math.ceil(ancho) + 1, 30),
            BackgroundTransparency = 1,
        }, fila)

        if ch ~= " " then
            local etiqueta = crear("TextLabel", {
                Size = UDim2.fromScale(1, 1),
                BackgroundTransparency = 1,
                Text = ch,
                Font = FUENTE,
                TextSize = tam,
                TextColor3 = ROJO,
                TextTransparency = 1,
            }, slot)
            local trazo = crear("UIStroke", {
                Color = ROJO_OSCURO,
                Thickness = 1.5,
                Transparency = 1,
            }, etiqueta)

            table.insert(letras, {
                label = etiqueta,
                stroke = trazo,
                f1 = math.random() * math.pi * 2,
                f2 = math.random() * math.pi * 2,
                v1 = 1.6 + math.random() * 1.6,
                v2 = 3.0 + math.random() * 2.2,
                parpadeoEn = os.clock() + 2 + math.random() * 8,
                parpadeoHasta = 0,
            })
        end
    end

    return letras
end

local function lineaTexto(padre, nombre, orden, texto)
    local l = crear("TextLabel", {
        Name = nombre,
        LayoutOrder = orden,
        Size = UDim2.new(1, 0, 0, 16),
        BackgroundTransparency = 1,
        RichText = true,
        Text = texto,
        Font = FUENTE,
        TextSize = 14,
        TextColor3 = ROSA,
        TextTransparency = 1,
    }, padre)
    local t = crear("UIStroke", { Color = Color3.new(0, 0, 0), Thickness = 1, Transparency = 1 }, l)
    return l, t
end

local function crearCaja(carpeta, parte, visible)
    return crear("BoxHandleAdornment", {
        Name = "Caja_" .. parte.Name,
        Adornee = parte,
        Size = parte.Size,
        Color3 = Color3.fromRGB(255, 40, 40),
        Transparency = 1,
        AlwaysOnTop = true,
        ZIndex = 5,
        Visible = visible,
    }, carpeta)
end

-- ── Ciclo de vida de cada objetivo ───────────────────────────────
local function destruirObjetivo(player)
    local d = objetivos[player]
    if not d then return end
    objetivos[player] = nil

    for _, c in ipairs(d.conexiones) do c:Disconnect() end
    if d.gui then d.gui:Destroy() end
    if d.highlight then d.highlight:Destroy() end
    if d.carpeta then d.carpeta:Destroy() end

    if nombresOcultos and d.humanoid.Parent then
        d.humanoid.DisplayDistanceType = d.displayOriginal
    end
end

local function fijarVisible(d, v)
    if d.visible == v then return end
    d.visible = v
    d.gui.Enabled = v
    if d.highlight then d.highlight.Enabled = v end
    for _, c in ipairs(d.cajas) do c.caja.Visible = v end
end

-- Datos que cambian poco (10 veces por segundo): vida, texto, tamaños
local function actualizarLento(d, ahora)
    local h = d.humanoid
    local hp, maxHp = h.Health, h.MaxHealth

    local frac
    if hp ~= hp or hp <= 0 then
        frac = 0
    elseif maxHp ~= maxHp or maxHp <= 0 or maxHp == math.huge then
        frac = 1
    else
        frac = clamp01(hp / maxHp)
    end
    if frac ~= frac then frac = 1 end

    d.muerto = (hp ~= hp) or hp <= 0
    d.urg = d.muerto and 0 or clamp01((0.35 - frac) / 0.35)
    if frac < d.fracPrev - 0.001 then d.ultimoDano = ahora end
    d.fracPrev = frac
    d.frac = frac

    if d.textoVida then
        local g = math.floor(60 + 140 * frac)
        local color = Color3.fromRGB(255, g, g)
        local maxTxt = (maxHp == math.huge) and "inf" or tostring(entero(maxHp))
        local texto = string.format('Vida: <font color="%s">%d/%s</font>',
            rgbTag(color), entero(hp), maxTxt)
        if texto ~= d.textoVidaActual then
            d.textoVidaActual = texto
            d.textoVida.Text = texto
        end
    end

    for _, c in ipairs(d.cajas) do
        if c.parte.Parent then
            local s = c.parte.Size
            if c.caja.Size ~= s then c.caja.Size = s end
        end
    end
end

local function crearObjetivo(player, character)
    if creando[player] == character then return end
    local previo = objetivos[player]
    if previo and previo.char == character then return end
    creando[player] = character

    local humanoid = character:WaitForChild("Humanoid", 10)
    local head     = character:WaitForChild("Head", 10)
    local root     = character:WaitForChild("HumanoidRootPart", 10)

    if creando[player] ~= character then return end -- llegó un personaje más nuevo
    creando[player] = nil
    if not (humanoid and head and root) then return end
    if not character:IsDescendantOf(workspace) then return end

    destruirObjetivo(player)

    local d = {
        player = player, char = character,
        humanoid = humanoid, head = head, root = root,
        conexiones = {}, cajas = {},
        displayOriginal = humanoid.DisplayDistanceType,
        visible = false, muerto = false,
        frac = 1, fracVis = 1, fracFantasma = 1, fracPrev = 1,
        ultimoDano = -100, urg = 0,
        fasePulso = math.random() * math.pi * 2,
        proximoLento = 0, textoVidaActual = "",
        revInicio = 0,
    }

    -- Resplandor rojo suave
    if CONFIG.resplandor then
        local viejo = character:FindFirstChild("ESP_Rojo")
        if viejo then viejo:Destroy() end
        d.highlight = crear("Highlight", {
            Name = "ESP_Rojo",
            Adornee = character,
            FillColor = Color3.fromRGB(255, 90, 90),
            OutlineColor = Color3.fromRGB(255, 60, 60),
            FillTransparency = 1,
            OutlineTransparency = 1,
            DepthMode = Enum.HighlightDepthMode.AlwaysOnTop,
            Enabled = false,
        }, character)
    end

    -- Hitbox roja transparente
    if CONFIG.hitbox then
        local viejo = character:FindFirstChild("HitboxShinigami")
        if viejo then viejo:Destroy() end
        d.carpeta = crear("Folder", { Name = "HitboxShinigami" }, character)

        if CONFIG.hitboxModo == "raiz" then
            table.insert(d.cajas, { caja = crearCaja(d.carpeta, root, false), parte = root })
        else
            for _, parte in ipairs(character:GetChildren()) do
                if parte:IsA("BasePart") and parte ~= root then
                    table.insert(d.cajas, { caja = crearCaja(d.carpeta, parte, false), parte = parte })
                end
            end
            -- Las partes del R15 pueden cargar tarde: las agregamos cuando aparezcan
            table.insert(d.conexiones, character.ChildAdded:Connect(function(hijo)
                if hijo:IsA("BasePart") and hijo ~= root then
                    table.insert(d.cajas, { caja = crearCaja(d.carpeta, hijo, d.visible), parte = hijo })
                end
            end))
        end
    end

    -- Etiqueta flotante
    local viejaEtiqueta = head:FindFirstChild("EtiquetaShinigami")
    if viejaEtiqueta then viejaEtiqueta:Destroy() end

    d.gui = crear("BillboardGui", {
        Name = "EtiquetaShinigami",
        Adornee = head,
        Size = UDim2.fromOffset(340, 150),
        StudsOffset = Vector3.new(0, 2.7, 0),
        AlwaysOnTop = true,
        LightInfluence = 0,
        MaxDistance = CONFIG.distanciaMaxima + 20,
        Enabled = false,
    }, head)

    local contenido = crear("Frame", {
        Name = "Contenido",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
    }, d.gui)
    d.escala = crear("UIScale", { Scale = 1 }, contenido)
    crear("UIListLayout", {
        FillDirection = Enum.FillDirection.Vertical,
        HorizontalAlignment = Enum.HorizontalAlignment.Center,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 3),
    }, contenido)

    local fila = crear("Frame", {
        Name = "Nombre",
        LayoutOrder = 1,
        Size = UDim2.new(1, 0, 0, 30),
        BackgroundTransparency = 1,
    }, contenido)
    crear("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        HorizontalAlignment = Enum.HorizontalAlignment.Center,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 1),
    }, fila)
    d.letras = crearLetras(fila, nombreMostrado(player))

    -- Barra de vida con "estela" de daño
    if CONFIG.mostrarBarraVida then
        d.pista = crear("Frame", {
            Name = "Pista",
            LayoutOrder = 2,
            Size = UDim2.fromOffset(170, 6),
            BackgroundColor3 = Color3.fromRGB(35, 0, 0),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
        }, contenido)
        crear("UICorner", { CornerRadius = UDim.new(1, 0) }, d.pista)
        d.pistaTrazo = crear("UIStroke", {
            Color = ROJO,
            Thickness = 1,
            Transparency = 1,
            ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        }, d.pista)
        d.fantasma = crear("Frame", {
            Name = "Estela",
            Size = UDim2.fromScale(1, 1),
            BackgroundColor3 = ROSA,
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
        }, d.pista)
        crear("UICorner", { CornerRadius = UDim.new(1, 0) }, d.fantasma)
        d.relleno = crear("Frame", {
            Name = "Vida",
            Size = UDim2.fromScale(1, 1),
            BackgroundColor3 = ROJO,
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
        }, d.pista)
        crear("UICorner", { CornerRadius = UDim.new(1, 0) }, d.relleno)
    end

    if CONFIG.mostrarId then
        d.textoId, d.trazoId = lineaTexto(contenido, "Id", 3, "ID: " .. tostring(player.UserId))
    end
    if CONFIG.mostrarVida then
        d.textoVida, d.trazoVida = lineaTexto(contenido, "Vida", 4, "")
    end

    -- Estado inicial
    local ahora = os.clock()
    if activo then
        d.revInicio = math.max(ahora, tToggle + 0.24 + distanciaA(d, camaraPos()) * 0.004)
    else
        d.revInicio = ahora
    end

    objetivos[player] = d
    if nombresOcultos then
        humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
    end

    actualizarLento(d, ahora)
    d.fracVis, d.fracFantasma = d.frac, d.frac
end

-- ── Animación por fotograma de cada objetivo ─────────────────────
local function actualizarObjetivo(d, ahora, dt, camPos)
    if ahora >= d.proximoLento then
        d.proximoLento = ahora + 0.1
        if not d.char:IsDescendantOf(workspace) then
            destruirObjetivo(d.player)
            return
        end
        actualizarLento(d, ahora)
    end

    local dist = distanciaA(d, camPos)
    local dMax = CONFIG.distanciaMaxima
    local dIni = dMax * CONFIG.inicioDesvanecido
    local porDistancia = 1 - suave((dist - dIni) / math.max(dMax - dIni, 1))
    local alpha = gAlpha * porDistancia * (d.muerto and 0.55 or 1)

    if alpha <= 0.004 then
        fijarVisible(d, false)
        return
    end
    fijarVisible(d, true)

    local rev = clamp01((ahora - d.revInicio) / CONFIG.duracionReveal)
    local urg = d.urg

    -- La etiqueta sube un poco con la distancia para no taparle la cabeza
    d.gui.StudsOffset = Vector3.new(0, 2.6 + math.min(dist, dMax) * 0.02, 0)
    d.escala.Scale = lerp(1, CONFIG.escalaLejos, clamp01(dist / dMax))
        * (1 + (1 - suave(rev)) * 0.18)

    -- Nombre: cada letra aparece en cadena y luego flota por su cuenta
    local n = #d.letras
    local velPulso = 3 + urg * 7 -- con poca vida el nombre late más rápido
    for i, L in ipairs(d.letras) do
        local arranque = (i - 1) / n * 0.55
        local la = suave((rev - arranque) / 0.45)

        local mov = math.sin(ahora * L.v1 + L.f1) * 0.65 + math.sin(ahora * L.v2 + L.f2) * 0.35
        local y = mov * CONFIG.amplitudLetras - (1 - la) * (1 - la) * 14
        local x = 0
        if urg > 0.05 then
            x = math.sin(ahora * 45 + L.f2) * urg * 1.3 -- temblor
        end
        L.label.Position = UDim2.fromOffset(x, y)
        L.label.Rotation = math.sin(ahora * L.v2 * 0.7 + L.f1) * CONFIG.giroLetras

        local fl = 1
        if CONFIG.titileoLetras then
            if ahora >= L.parpadeoEn then
                L.parpadeoHasta = ahora + 0.07
                L.parpadeoEn = ahora + 3 + math.random() * 8
            end
            if ahora < L.parpadeoHasta then fl = 0.2 end
        end

        local pulso = (math.sin(ahora * velPulso + L.f1) + 1) / 2
        local vis = la * fl * alpha
        L.label.TextTransparency = 1 - vis
        L.stroke.Transparency = lerp(1, 0.25 + pulso * 0.35, vis)
        if d.muerto then
            L.label.TextColor3 = GRIS
        else
            L.label.TextColor3 = ROJO:Lerp(ROJO_VIVO, pulso * (0.35 + urg * 0.65))
        end
    end

    -- ID, vida y barra: aparecen después del nombre
    local ia = suave((rev - 0.45) / 0.55) * alpha
    if d.textoId then
        d.textoId.TextTransparency = 1 - ia
        d.trazoId.Transparency = 1 - 0.7 * ia
    end
    if d.textoVida then
        d.textoVida.TextTransparency = 1 - ia
        d.trazoVida.Transparency = 1 - 0.7 * ia
    end

    local pulsoC = (math.sin(ahora * (2.2 + urg * 4) + d.fasePulso) + 1) / 2

    if d.relleno then
        d.fracVis = d.fracVis + (d.frac - d.fracVis) * (1 - math.exp(-dt * 10))
        if d.frac > d.fracFantasma then
            d.fracFantasma = d.frac
        elseif ahora - d.ultimoDano > 0.45 then
            d.fracFantasma = d.fracFantasma + (d.frac - d.fracFantasma) * (1 - math.exp(-dt * 2.2))
        end
        d.relleno.Size = UDim2.fromScale(d.fracVis, 1)
        d.fantasma.Size = UDim2.fromScale(math.max(d.fracFantasma, d.fracVis), 1)

        d.pista.BackgroundTransparency = 1 - 0.6 * ia
        d.pistaTrazo.Transparency = 1 - 0.85 * ia
        d.fantasma.BackgroundTransparency = 1 - 0.75 * ia
        d.relleno.BackgroundTransparency = 1 - ia
        if d.muerto then
            d.relleno.BackgroundColor3 = GRIS
        else
            d.relleno.BackgroundColor3 = ROJO:Lerp(BLANCO, pulsoC * urg * 0.5)
        end
    end

    -- Resplandor y hitbox: aparecen con la "ola" de escaneo y respiran suave
    local ra = alpha * suave(rev * 2)
    if d.highlight then
        d.highlight.FillTransparency = 1 - 0.35 * ra * (0.85 + 0.15 * pulsoC)
        d.highlight.OutlineTransparency = 1 - 0.7 * ra * (0.75 + 0.25 * pulsoC)
    end
    if #d.cajas > 0 then
        local t = 1 - (1 - CONFIG.hitboxTransparencia) * ra * (0.8 + 0.2 * pulsoC)
        for _, c in ipairs(d.cajas) do
            c.caja.Transparency = t
        end
    end
end

-- ── Efectos globales: parpadeo, viñeta, tinte, desenfoque, cartel ─
local vigActual, tintActual = 0, 0
local cobPrev, vigPrev, blurPrev, avisoPrev = -1, -1, -1, -1

local function actualizarGlobal(ahora, dt)
    local s = ahora - tToggle

    -- visibilidad general
    if activo then
        gAlpha = math.min(1, gAlpha + dt * 6)
    else
        gAlpha = math.max(0, gAlpha - dt * 3.5)
    end

    -- Con los ojos activos se esconden los nombres normales de Roblox;
    -- al apagarlos vuelven a como estaban
    if gAlpha > 0.002 and not nombresOcultos then
        nombresOcultos = true
        for _, d in pairs(objetivos) do
            d.humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
        end
    elseif gAlpha <= 0.002 and nombresOcultos then
        nombresOcultos = false
        for _, d in pairs(objetivos) do
            if d.humanoid.Parent then
                d.humanoid.DisplayDistanceType = d.displayOriginal
            end
        end
    end

    -- Parpadeo: se cierra rápido y se abre despacio
    if #tapas > 0 then
        local c = 0
        if s < 0.10 then
            c = suave(s / 0.10)
        elseif s < 0.16 then
            c = 1
        elseif s < 0.62 then
            c = 1 - suave((s - 0.16) / 0.46)
        end
        if c ~= cobPrev then
            cobPrev = c
            local tam = UDim2.fromScale(1, 0.5 * c)
            tapas[1].Size = tam
            tapas[2].Size = tam
        end
    end

    -- Destello suave al abrir los ojos
    local flash = 0
    if activo and s > 0.14 and s < 1.2 then
        flash = 1 - suave((s - 0.14) / 1.06)
    end

    -- Viñeta roja
    if #bordes > 0 then
        local objetivoVig = activo and CONFIG.vinetaIntensidad or 0
        vigActual = vigActual + (objetivoVig - vigActual) * (1 - math.exp(-dt * 5))
        local v = 1 - clamp01(vigActual + flash * 0.5)
        if math.abs(v - vigPrev) > 0.002 then
            vigPrev = v
            for _, f in ipairs(bordes) do
                f.BackgroundTransparency = v
            end
        end
    end

    -- Tinte rojo casi imperceptible
    local objetivoTinte = (activo and CONFIG.tinte) and 1 or 0
    tintActual = tintActual + (objetivoTinte - tintActual) * (1 - math.exp(-dt * 3))
    local col = BLANCO:Lerp(CONFIG.tinteColor, tintActual)
    if flash > 0 then
        col = col:Lerp(Color3.fromRGB(255, 165, 165), flash * 0.45)
    end
    correccion.TintColor = col

    -- Desenfoque breve durante el parpadeo
    if CONFIG.desenfoque > 0 then
        local b = 0
        if s < 0.7 then
            b = math.sin(math.pi * s / 0.7) * CONFIG.desenfoque
        end
        if b ~= blurPrev then
            blurPrev = b
            desenfoque.Size = b
        end
    end

    -- Cartel
    if avisoTitulo then
        local a = 0
        if s > 0.3 and s < 2.6 then
            a = clamp01(math.min((s - 0.3) / 0.35, (2.6 - s) / 0.5))
        end
        if a ~= avisoPrev then
            avisoPrev = a
            avisoTitulo.TextTransparency = 1 - a
            avisoTrazoT.Transparency = 1 - 0.7 * a
            avisoSub.TextTransparency = 1 - 0.85 * a
            avisoTrazoS.Transparency = 1 - 0.6 * a
        end
    end
end

-- ── Encender / apagar ────────────────────────────────────────────
local function establecerActivo(valor)
    local ahora = os.clock()
    activo = valor
    tToggle = ahora

    if valor then
        -- la "ola de escaneo" llega primero a los más cercanos
        local camPos = camaraPos()
        for _, d in pairs(objetivos) do
            d.revInicio = ahora + 0.24 + distanciaA(d, camPos) * 0.004
        end
    end

    if avisoSub then
        avisoSub.Text = valor and "activados" or "desactivados"
    end
    reproducir(valor and CONFIG.sonidoEncender or CONFIG.sonidoApagar)
end

local function alternar()
    if os.clock() - tToggle < 0.7 then return end -- evita spam de la tecla
    establecerActivo(not activo)
end

UserInputService.InputBegan:Connect(function(input, procesado)
    if procesado then return end
    if input.KeyCode == CONFIG.tecla then
        alternar()
    end
end)

if boton then
    boton.Activated:Connect(alternar)
end

-- ── Jugadores ────────────────────────────────────────────────────
local function conectarJugador(player)
    if player == localPlayer or conexiones[player] then return end

    conexiones[player] = {
        player.CharacterAdded:Connect(function(personaje)
            task.spawn(crearObjetivo, player, personaje)
        end),
        player.CharacterRemoving:Connect(function()
            destruirObjetivo(player)
        end),
    }

    if player.Character then
        task.spawn(crearObjetivo, player, player.Character)
    end
end

Players.PlayerRemoving:Connect(function(player)
    local lista = conexiones[player]
    if lista then
        for _, c in ipairs(lista) do c:Disconnect() end
        conexiones[player] = nil
    end
    destruirObjetivo(player)
    creando[player] = nil
end)

-- ── Bucle principal ──────────────────────────────────────────────
RunService.RenderStepped:Connect(function(dt)
    dt = math.min(dt, 0.1)
    local ahora = os.clock()

    actualizarGlobal(ahora, dt)

    if gAlpha <= 0.002 then
        if not todoOculto then
            todoOculto = true
            for _, d in pairs(objetivos) do
                fijarVisible(d, false)
            end
        end
        return
    end
    todoOculto = false

    local camPos = camaraPos()
    for _, d in pairs(objetivos) do
        actualizarObjetivo(d, ahora, dt, camPos)
    end
end)

-- Respaldo: cada 1.5 s revisa que todos tengan su etiqueta
task.spawn(function()
    while true do
        task.wait(1.5)
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= localPlayer then
                local personaje = player.Character
                local d = objetivos[player]
                if personaje and creando[player] ~= personaje and (not d or d.char ~= personaje) then
                    task.spawn(crearObjetivo, player, personaje)
                end
            end
        end
    end
end)

-- ── Arranque ─────────────────────────────────────────────────────
if CONFIG.empezarActivo then
    establecerActivo(true)
end

for _, player in ipairs(Players:GetPlayers()) do
    conectarJugador(player)
end
Players.PlayerAdded:Connect(conectarJugador)
