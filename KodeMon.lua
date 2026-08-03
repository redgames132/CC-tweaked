-- =======================================================
-- AETHERIA 5.1 - UI DINÂMICA (PERFEITA PARA MONITOR 6X3)
-- =======================================================
local mon = peripheral.find("monitor")
local listaSpeakers = {peripheral.find("speaker")}

local speakerSFX = listaSpeakers[1]
local speakerBGM = listaSpeakers[2] or listaSpeakers[1]

if not mon then print("[ERRO] Monitor nao encontrado!") return end

-- PALETA CUSTOMIZADA
mon.setPaletteColor(colors.lime, 0x8bbf54)       -- Grama base
mon.setPaletteColor(colors.green, 0x5a8a32)      -- Grama Alta
mon.setPaletteColor(colors.blue, 0x4a9cc2)       -- Agua
mon.setPaletteColor(colors.lightBlue, 0x3d404d)  -- Mina
mon.setPaletteColor(colors.gray, 0x737a80)       -- Montanhas
mon.setPaletteColor(colors.yellow, 0xf2c94c)     -- UI e Ouro
mon.setPaletteColor(colors.red, 0xe05656)        -- Botoes / Fogo
mon.setPaletteColor(colors.cyan, 0x47e8cd)       -- Cristais Magicos
mon.setPaletteColor(colors.white, 0xffffff)      -- Esferas de Captura

local ESTADO = "MENU"
local rodando = true
local volume = 1.0
local mensagemLog = "Bem-vindo a Aetheria!"

local config = { musica = true, trilha = 1 }

local jogador = { 
    x = 0, y = 0, nivel = 1, xp = 0, hp = 100, maxHp = 100,
    ouro = 0, pocoes = 5, esferas = 3,
    monstro = "Nenhum", tipo = "Normal",
    coletados = {}, slotAtivo = 1
}
local inimigoAtual = nil

local bestiario = {
    {nome="Gota Selvagem", tipo="Agua", hp=40, dano=10, xp=15, cor=colors.blue, arte={"  _  "," / \\ ","(o.o)"," --- "}},
    {nome="Espirito Folha", tipo="Planta", hp=45, dano=12, xp=15, cor=colors.green, arte={" \\|/ ","-o.o-"," /|\\ ","     "}},
    {nome="Lobo de Chamas", tipo="Fogo", hp=60, dano=18, xp=25, cor=colors.red, arte={" /\\/\\ ","( o.o)"," >^^< ","      "}},
    {nome="Tartaruga Rio", tipo="Agua", hp=80, dano=14, xp=30, cor=colors.blue, arte={"  ___  "," /o o\\ ","(_____)","       "}},
    {nome="Tronco Vivo", tipo="Planta", hp=90, dano=20, xp=40, cor=colors.brown, arte={" [~~~] "," [o.o] "," /[ ]\\ ","       "}},
    {nome="Morcego Mina", tipo="Fogo", hp=50, dano=22, xp=20, cor=colors.red, arte={" ^   ^ "," \\o_o/ "," / | \\ ","       "}}
}

local chefes = {
    {nome="TITAN DE GELO", tipo="Agua", hp=300, dano=30, xp=200, cor=colors.cyan, arte={" /\\/\\/\\ "," |O..O| "," |____| "," /\\/\\/\\ "}},
    {nome="DRAGAO CELESTE", tipo="Fogo", hp=600, dano=55, xp=500, cor=colors.red, arte={" \\||||/ "," (O__O) "," /|  |\\ ","  |__|  "}}
}

-- =======================================================
-- SISTEMA DE SAVES
-- =======================================================
local function salvarJogo()
    local f = fs.open("aetheria_slot" .. jogador.slotAtivo .. ".json", "w")
    f.write(textutils.serialize(jogador))
    f.close()
end

local function lerSaveInfo(slot)
    local arquivo = "aetheria_slot" .. slot .. ".json"
    if fs.exists(arquivo) then
        local f = fs.open(arquivo, "r")
        local dados = textutils.unserialize(f.readAll())
        f.close()
        if dados then return string.format("SLOT %d: %s (Lv %d)", slot, dados.monstro, dados.nivel) end
    end
    return string.format("SLOT %d: [VAZIO]", slot)
end

local function carregarJogo(slot)
    local arquivo = "aetheria_slot" .. slot .. ".json"
    if fs.exists(arquivo) then
        local f = fs.open(arquivo, "r")
        jogador = textutils.unserialize(f.readAll())
        f.close()
        jogador.coletados = jogador.coletados or {}
        jogador.esferas = jogador.esferas or 3
        jogador.slotAtivo = slot
        return true
    end
    return false
end

-- =======================================================
-- AUDIO 8-BIT
-- =======================================================
local function tocar(instrumento, pitch)
    if speakerSFX then pcall(function() speakerSFX.playNote(instrumento, volume, pitch) end) end
end

local trilhas = {
    { nome = "Tema Principal", notas = {
        {12,0.2},{16,0.2},{19,0.2},{16,0.2},{12,0.2},{16,0.2},{19,0.4},
        {14,0.2},{17,0.2},{21,0.2},{17,0.2},{14,0.2},{17,0.2},{21,0.4},
        {10,0.2},{14,0.2},{17,0.2},{14,0.2},{10,0.2},{14,0.2},{17,0.4},
        {12,0.2},{16,0.2},{19,0.2},{24,0.2},{19,0.2},{16,0.2},{12,0.5}
    }},
    { nome = "Flower Man", notas = {
        {12,0.2},{12,0.2},{19,0.4},{21,0.2},{21,0.2},{19,0.4},
        {17,0.2},{17,0.2},{16,0.4},{14,0.2},{14,0.2},{12,0.6},
        {19,0.2},{19,0.2},{16,0.4},{14,0.2},{14,0.2},{12,0.4}
    }}
}

local function loopMusica()
    local idx = 1
    local ultimaTrilha = config.trilha
    while rodando do
        if ultimaTrilha ~= config.trilha then idx = 1; ultimaTrilha = config.trilha end
        
        if config.musica and speakerBGM and (ESTADO == "MAPA" or ESTADO == "BATALHA" or ESTADO == "CONFIG") then
            local faixa = trilhas[config.trilha].notas
            if idx > #faixa then idx = 1 end
            local nota = faixa[idx]
            
            pcall(function() speakerBGM.playNote("harp", volume * 0.5, nota[1]) end)
            idx = idx + 1; os.sleep(nota[2])
        else
            os.sleep(0.5)
        end
    end
end
tocar("chime", 12)

-- =======================================================
-- GERADOR DE BIOMAS
-- =======================================================
local function getTile(wx, wy)
    if wx >= -1 and wx <= 1 and wy >= -1 and wy <= 1 then return {bg=colors.yellow, fg=colors.white, char="*", type="spawn"} end
    
    local posKey = wx..","..wy
    local hash = math.abs((wx * 1337) + (wy * 99991)) % 1000
    
    if not jogador.coletados[posKey] then
        if hash < 5 then return {bg=colors.magenta, fg=colors.white, char="H", type="chefe"} end
        if hash < 20 then return {bg=colors.cyan, fg=colors.white, char="+", type="cura"} end
        if hash > 100 and hash < 115 then return {bg=colors.yellow, fg=colors.black, char="$", type="ouro"} end
        if hash > 115 and hash < 125 then return {bg=colors.white, fg=colors.red, char="O", type="esfera"} end
    end
    
    local ruido = math.sin(wx * 0.3) + math.cos(wy * 0.3) + math.sin((wx+wy) * 0.1)
    local ruido2 = math.cos(wx * 0.1) + math.sin(wy * 0.2)
    
    if ruido2 > 0.8 then return {bg=colors.lightBlue, fg=colors.gray, char="m", type="mina"} end
    if ruido < -1.0 then return {bg=colors.blue, fg=colors.cyan, char="~", type="agua"} end
    if ruido > 1.2 then return {bg=colors.gray, fg=colors.lightGray, char="^", type="montanha"} end
    if ruido > 0.5 then return {bg=colors.green, fg=colors.lime, char="\"", type="grama_alta"} end
    
    return {bg=colors.lime, fg=colors.green, char=".", type="grama"}
end

-- =======================================================
-- UTILITARIOS DE TELA
-- =======================================================
local function centralizar(x_start, largura, y, texto, corTexto, corFundo)
    local x = x_start + math.floor((largura - #texto) / 2)
    mon.setCursorPos(math.max(x_start, x), y)
    mon.setTextColor(corTexto or colors.white)
    if corFundo then mon.setBackgroundColor(corFundo) end
    mon.write(texto)
end

local function desenharBotao(x, y, larg, alt, texto, corFundo, corTexto)
    mon.setBackgroundColor(corFundo)
    for i=0, alt-1 do mon.setCursorPos(x, y+i); mon.write(string.rep(" ", larg)) end
    mon.setCursorPos(x + math.floor((larg - #texto)/2), y + math.floor(alt/2))
    mon.setTextColor(corTexto); mon.write(texto)
end

-- =======================================================
-- RENDERIZADOR (ADAPTADO PARA 6X3)
-- =======================================================
local function desenharMenu()
    mon.setBackgroundColor(colors.black); mon.clear()
    local larg, alt = mon.getSize()
    centralizar(1, larg, 4, "A E T H E R I A", colors.yellow, colors.black)
    desenharBotao(math.floor(larg/2)-10, 8, 20, 2, "JOGAR", colors.lime, colors.black)
end

local function desenharSaves()
    mon.setBackgroundColor(colors.black); mon.clear()
    local larg, alt = mon.getSize()
    centralizar(1, larg, 2, "SELECIONE UM ARQUIVO DE JOGO", colors.cyan, colors.black)
    
    desenharBotao(math.floor(larg/2)-15, 5, 30, 2, lerSaveInfo(1), colors.gray, colors.white)
    desenharBotao(math.floor(larg/2)-15, 8, 30, 2, lerSaveInfo(2), colors.gray, colors.white)
    desenharBotao(math.floor(larg/2)-15, 11, 30, 2, lerSaveInfo(3), colors.gray, colors.white)
end

local function desenharEscolha()
    mon.setBackgroundColor(colors.black); mon.clear()
    local larg, alt = mon.getSize()
    centralizar(1, larg, 3, "ESCOLHA SEU AETHER INICIAL", colors.white, colors.black)
    
    desenharBotao(math.floor(larg/2)-25, 8, 14, 2, "IGNIS (FOGO)", colors.red, colors.white)
    desenharBotao(math.floor(larg/2)-7, 8, 14, 2, "AQUA (AGUA)", colors.blue, colors.white)
    desenharBotao(math.floor(larg/2)+11, 8, 15, 2, "FLORA (PLANTA)", colors.green, colors.white)
end

local function desenharConfig()
    mon.setBackgroundColor(colors.black); mon.clear()
    local larg, alt = mon.getSize()
    centralizar(1, larg, 2, "--- MENU DE CONFIGURACOES ---", colors.cyan, colors.black)
    
    local txtMusica = config.musica and "MUSICA: [ LIGADA ]" or "MUSICA: [ MUTADA ]"
    desenharBotao(math.floor(larg/2)-15, 5, 30, 2, txtMusica, colors.gray, colors.white)
    
    local txtTrilha = "TRILHA: " .. trilhas[config.trilha].nome
    desenharBotao(math.floor(larg/2)-15, 8, 30, 2, txtTrilha, colors.gray, colors.white)
    
    desenharBotao(math.floor(larg/2)-15, 11, 30, 2, "TROCAR DE SAVE", colors.red, colors.white)
    desenharBotao(math.floor(larg/2)-15, 14, 30, 2, "VOLTAR AO MAPA", colors.blue, colors.white)
end

local function desenharMapa()
    mon.setBackgroundColor(colors.black); mon.clear()
    local larg, alt = mon.getSize()
    local viewLarg = larg - 24 
    local cx = math.floor(viewLarg / 2)
    local cy = math.floor(alt / 2)
    
    for screenY = 1, alt do
        for screenX = 1, viewLarg do
            local worldX = jogador.x + (screenX - cx)
            local worldY = jogador.y + (screenY - cy)
            local tile = getTile(worldX, worldY)
            
            mon.setCursorPos(screenX, screenY); mon.setBackgroundColor(tile.bg)
            if screenX == cx and screenY == cy then
                mon.setTextColor(colors.white); mon.write("@")
            else
                mon.setTextColor(tile.fg); mon.write(tile.char)
            end
        end
    end
    
    local painelX = viewLarg + 1
    mon.setBackgroundColor(colors.black)
    for i=1, alt do mon.setCursorPos(painelX, i); mon.write(string.rep(" ", 24)) end
    mon.setBackgroundColor(colors.gray)
    for i=1, alt do mon.setCursorPos(painelX, i); mon.write(" ") end
    
    -- Ajustado para caber em monitores de altura 19 (6x3)
    centralizar(painelX+1, 23, 1, "A E T H E R I A", colors.yellow, colors.black)
    centralizar(painelX+1, 23, 2, jogador.monstro .. " ("..jogador.tipo..")", colors.cyan, colors.black)
    centralizar(painelX+1, 23, 3, string.format("Lvl:%d | XP:%d", jogador.nivel, jogador.xp), colors.white, colors.black)
    
    mon.setCursorPos(painelX+2, 5); mon.setBackgroundColor(colors.gray); mon.write(string.rep(" ", 20))
    local hpFill = math.floor((jogador.hp / jogador.maxHp) * 20)
    if hpFill > 0 then
        mon.setCursorPos(painelX+2, 5); mon.setBackgroundColor(colors.lime); mon.write(string.rep(" ", hpFill))
    end
    mon.setBackgroundColor(colors.black)
    
    centralizar(painelX+1, 23, 7, "Ouro: "..jogador.ouro.." | Esf: "..jogador.esferas, colors.yellow, colors.black)
    centralizar(painelX+1, 23, 9, mensagemLog, colors.lime, colors.black)
    
    -- D-Pad e Config Dinamicos baseados na altura total
    local by = alt - 8
    desenharBotao(painelX + 9, by, 6, 2, "/\\", colors.gray, colors.white)
    desenharBotao(painelX + 2, by+2, 6, 2, "<", colors.gray, colors.white)
    desenharBotao(painelX + 16, by+2, 6, 2, ">", colors.gray, colors.white)
    desenharBotao(painelX + 9, by+4, 6, 2, "\\/", colors.gray, colors.white)
    
    desenharBotao(painelX + 2, alt - 1, 20, 2, "CONFIG", colors.blue, colors.white)
end

local function desenharBatalha()
    mon.setBackgroundColor(colors.black); mon.clear()
    local larg, alt = mon.getSize()
    
    mon.setCursorPos(1, 1); mon.setBackgroundColor(colors.yellow); mon.write(string.rep(" ", larg))
    centralizar(1, larg, 1, "BATALHA: " .. jogador.monstro .. " VS " .. inimigoAtual.nome, colors.black, colors.yellow)

    if inimigoAtual then
        centralizar(1, larg, 3, inimigoAtual.nome .. " (" .. inimigoAtual.tipo .. ")", inimigoAtual.cor, colors.black)
        centralizar(1, larg, 4, "HP: " .. inimigoAtual.hp .. " / " .. inimigoAtual.maxHp, colors.red, colors.black)
        for i, linha in ipairs(inimigoAtual.arte) do centralizar(1, larg, 5 + i, linha, inimigoAtual.cor, colors.black) end
    end

    mon.setCursorPos(4, alt - 5); mon.setTextColor(colors.cyan); mon.setBackgroundColor(colors.black); mon.write(jogador.monstro .. " ("..jogador.tipo..")")
    mon.setCursorPos(4, alt - 4); mon.setTextColor(colors.white); mon.write(string.format("HP: %d / %d", jogador.hp, jogador.maxHp))
    
    mon.setBackgroundColor(colors.gray)
    for i=0, 1 do mon.setCursorPos(24, alt-5+i); mon.write(string.rep(" ", larg-25)) end
    mon.setCursorPos(26, alt-4); mon.setTextColor(colors.white); mon.write(mensagemLog)

    mon.setBackgroundColor(colors.black)
    if ESTADO == "BATALHA" then
        desenharBotao(4, alt - 2, 14, 2, "ATACAR", colors.red, colors.white)
        desenharBotao(20, alt - 2, 14, 2, "ITENS", colors.blue, colors.white)
        desenharBotao(36, alt - 2, 14, 2, "FUGIR", colors.yellow, colors.black)
    elseif ESTADO == "SUBMENU_ITEM" then
        desenharBotao(4, alt - 2, 16, 2, "POCAO ("..jogador.pocoes..")", colors.lime, colors.black)
        desenharBotao(22, alt - 2, 16, 2, "ESFERA ("..jogador.esferas..")", colors.white, colors.black)
        desenharBotao(40, alt - 2, 10, 2, "VOLTAR", colors.gray, colors.white)
    end
end

local function atualizarTela()
    mon.setTextScale(1)
    if ESTADO == "MENU" then desenharMenu()
    elseif ESTADO == "SAVES" then desenharSaves()
    elseif ESTADO == "ESCOLHA" then desenharEscolha()
    elseif ESTADO == "CONFIG" then desenharConfig()
    elseif ESTADO == "MAPA" then desenharMapa()
    elseif ESTADO == "BATALHA" or ESTADO == "SUBMENU_ITEM" then desenharBatalha()
    end
end

-- =======================================================
-- LOGICA DE MAPA E COMBATE
-- =======================================================
local function moverJogador(dx, dy)
    local nx = jogador.x + dx
    local ny = jogador.y + dy
    local tile = getTile(nx, ny)
    
    if tile.type == "agua" or tile.type == "montanha" then
        mensagemLog = "Caminho bloqueado!"; tocar("bass", 5); atualizarTela(); return
    end
    
    jogador.x = nx; jogador.y = ny; tocar("hat", 12)
    local posKey = nx..","..ny
    
    if tile.type == "cura" then
        jogador.hp = jogador.maxHp; jogador.coletados[posKey] = true; mensagemLog = "Curado pelo Cristal!"; tocar("chime", 15)
    elseif tile.type == "ouro" then
        jogador.ouro = jogador.ouro + math.random(10, 25); jogador.coletados[posKey] = true; mensagemLog = "Encontrou Ouro!"; tocar("chime", 20)
    elseif tile.type == "esfera" then
        jogador.esferas = jogador.esferas + 1; jogador.coletados[posKey] = true; mensagemLog = "Encontrou Esfera Aether!"; tocar("bell", 15)
    elseif tile.type == "chefe" then
        local boss = chefes[math.random(1, #chefes)]
        local mult = 1.0 + (jogador.nivel * 0.3)
        inimigoAtual = {nome=boss.nome, tipo=boss.tipo, maxHp=math.floor(boss.hp*mult), hp=math.floor(boss.hp*mult), dano=math.floor(boss.dano*mult), cor=boss.cor, arte=boss.arte, isBoss=true}
        mensagemLog = "O CHEFE APARECEU!"; tocar("bass", 2); ESTADO = "BATALHA"
    elseif tile.type == "grama_alta" or tile.type == "mina" then
        local chance = (tile.type == "mina") and 40 or 15
        if math.random(1, 100) <= chance then
            local monstro = bestiario[math.random(1, math.min(jogador.nivel + 1, #bestiario))]
            local mult = 1.0 + ((jogador.nivel - 1) * 0.15)
            inimigoAtual = {nome=monstro.nome, tipo=monstro.tipo, maxHp=math.floor(monstro.hp*mult), hp=math.floor(monstro.hp*mult), dano=math.floor(monstro.dano*mult), xp=math.floor(monstro.xp*mult), cor=monstro.cor, arte=monstro.arte, isBoss=false}
            mensagemLog = "Selvagem surgiu!"; tocar("cow_bell", 10); ESTADO = "BATALHA"
        else
            mensagemLog = (tile.type == "mina") and "Mina escura..." or "Grama alta..."
        end
    else
        mensagemLog = "Explorando..."
    end
    
    salvarJogo(); atualizarTela()
end

local function turnoInimigo()
    if inimigoAtual and inimigoAtual.hp > 0 then
        local dano = math.random(math.floor(inimigoAtual.dano * 0.7), inimigoAtual.dano)
        local mult = 1
        if inimigoAtual.tipo == "Fogo" and jogador.tipo == "Planta" then mult = 1.5 end
        if inimigoAtual.tipo == "Planta" and jogador.tipo == "Agua" then mult = 1.5 end
        if inimigoAtual.tipo == "Agua" and jogador.tipo == "Fogo" then mult = 1.5 end
        if mult > 1 then mensagemLog = "SUPER EFETIVO! " end
        
        dano = math.floor(dano * mult); jogador.hp = math.max(0, jogador.hp - dano)
        mensagemLog = mensagemLog .. inimigoAtual.nome .. " atacou!"; tocar("snare", 5)
        
        if jogador.hp <= 0 then
            jogador.hp = 0; mensagemLog = "DESMAIOU! Voltando..."; atualizarTela()
            tocar("bass", 1); os.sleep(3)
            jogador.x = 0; jogador.y = 0; jogador.hp = jogador.maxHp; ESTADO = "MAPA"; salvarJogo(); atualizarTela()
        end
    end
end

local function tentarCaptura()
    if jogador.esferas > 0 then
        jogador.esferas = jogador.esferas - 1; tocar("bell", 10)
        
        if inimigoAtual.isBoss then
            mensagemLog = "Impossivel capturar CHEFES!"; atualizarTela(); os.sleep(1); turnoInimigo()
        else
            local chanceTotal = 0.3 + ((1.0 - (inimigoAtual.hp / inimigoAtual.maxHp)) * 0.5)
            if math.random() <= chanceTotal then
                jogador.monstro = inimigoAtual.nome; jogador.tipo = inimigoAtual.tipo
                mensagemLog = "CAPTUROU " .. string.upper(inimigoAtual.nome) .. "!"
                tocar("chime", 20); atualizarTela(); os.sleep(2); ESTADO = "MAPA"; salvarJogo()
            else
                mensagemLog = "O monstro escapou!"; atualizarTela(); os.sleep(1); turnoInimigo()
            end
        end
    else mensagemLog = "Sem esferas!"; atualizarTela() end
end

local function vitoria()
    tocar("chime", 18); jogador.xp = jogador.xp + inimigoAtual.xp
    mensagemLog = "Vitoria! +" .. inimigoAtual.xp .. " XP"; atualizarTela(); os.sleep(1.5)
    
    if jogador.xp >= (jogador.nivel * 30) then
        jogador.xp = jogador.xp - (jogador.nivel * 30); jogador.nivel = jogador.nivel + 1
        jogador.maxHp = jogador.maxHp + 15; jogador.hp = jogador.maxHp
        mensagemLog = "MONSTRO SUBIU DE NIVEL!"; tocar("chime", 24); atualizarTela(); os.sleep(2)
    end
    ESTADO = "MAPA"; salvarJogo(); atualizarTela()
end

-- =======================================================
-- INPUTS E LOOP PRINCIPAL
-- =======================================================
local function loopJogo()
    atualizarTela()
    
    while rodando do
        local ev, _, x, y = os.pullEvent("monitor_touch")
        local larg, alt = mon.getSize()
        local painelX = (larg - 24) + 1
        
        if ESTADO == "MENU" then
            if y >= 8 and y <= 9 then ESTADO = "SAVES"; atualizarTela() end
            
        elseif ESTADO == "SAVES" then
            if y >= 5 and y <= 6 then
                if carregarJogo(1) then ESTADO = "MAPA" else jogador.slotAtivo=1; ESTADO = "ESCOLHA" end; atualizarTela()
            elseif y >= 8 and y <= 9 then
                if carregarJogo(2) then ESTADO = "MAPA" else jogador.slotAtivo=2; ESTADO = "ESCOLHA" end; atualizarTela()
            elseif y >= 11 and y <= 12 then
                if carregarJogo(3) then ESTADO = "MAPA" else jogador.slotAtivo=3; ESTADO = "ESCOLHA" end; atualizarTela()
            end
            
        elseif ESTADO == "ESCOLHA" then
            if y >= 8 and y <= 9 then
                jogador = {x=0, y=0, nivel=1, xp=0, hp=100, maxHp=100, ouro=0, pocoes=5, esferas=3, coletados={}, slotAtivo=jogador.slotAtivo}
                if x >= math.floor(larg/2)-25 and x <= math.floor(larg/2)-11 then jogador.monstro="Ignis"; jogador.tipo="Fogo"
                elseif x >= math.floor(larg/2)-7 and x <= math.floor(larg/2)+7 then jogador.monstro="Aqua"; jogador.tipo="Agua"
                elseif x >= math.floor(larg/2)+11 and x <= math.floor(larg/2)+26 then jogador.monstro="Flora"; jogador.tipo="Planta" end
                
                if jogador.monstro ~= "Nenhum" then tocar("chime", 12); salvarJogo(); ESTADO = "MAPA"; atualizarTela() end
            end
            
        elseif ESTADO == "CONFIG" then
            if y >= 5 and y <= 6 then
                config.musica = not config.musica; tocar("hat", 12); atualizarTela()
            elseif y >= 8 and y <= 9 then
                config.trilha = config.trilha + 1; if config.trilha > #trilhas then config.trilha = 1 end
                tocar("chime", 15); atualizarTela()
            elseif y >= 11 and y <= 12 then
                salvarJogo(); tocar("hat", 10); ESTADO = "SAVES"; atualizarTela()
            elseif y >= 14 and y <= 15 then
                tocar("hat", 10); ESTADO = "MAPA"; atualizarTela()
            end
            
        elseif ESTADO == "MAPA" then
            local by = alt - 8
            if y >= by and y <= by+1 and x >= painelX + 9 and x <= painelX + 14 then moverJogador(0, -1)
            elseif y >= by+4 and y <= by+5 and x >= painelX + 9 and x <= painelX + 14 then moverJogador(0, 1)
            elseif y >= by+2 and y <= by+3 and x >= painelX + 2 and x <= painelX + 7 then moverJogador(-1, 0)
            elseif y >= by+2 and y <= by+3 and x >= painelX + 16 and x <= painelX + 21 then moverJogador(1, 0)
            elseif y >= alt-1 and y <= alt and x >= painelX + 2 and x <= painelX + 21 then ESTADO = "CONFIG"; atualizarTela()
            end
            
        elseif ESTADO == "BATALHA" or ESTADO == "SUBMENU_ITEM" then
            if y >= alt - 2 and y <= alt - 1 then
                if ESTADO == "BATALHA" then
                    if x >= 4 and x <= 17 then
                        tocar("snare", 15); local dano = math.random(10 + (jogador.nivel*3), 15 + (jogador.nivel*5))
                        local mult = 1
                        if jogador.tipo == "Fogo" and inimigoAtual.tipo == "Planta" then mult = 1.5 end
                        if jogador.tipo == "Planta" and inimigoAtual.tipo == "Agua" then mult = 1.5 end
                        if jogador.tipo == "Agua" and inimigoAtual.tipo == "Fogo" then mult = 1.5 end
                        if mult > 1 then mensagemLog = "SUPER EFETIVO! " else mensagemLog = "" end
                        dano = math.floor(dano * mult); inimigoAtual.hp = inimigoAtual.hp - dano
                        mensagemLog = mensagemLog .. "Causou " .. dano .. " dano!"; atualizarTela(); os.sleep(1)
                        if inimigoAtual.hp <= 0 then vitoria() else turnoInimigo(); atualizarTela() end
                        
                    elseif x >= 20 and x <= 35 then ESTADO = "SUBMENU_ITEM"; atualizarTela()
                        
                    elseif x >= 38 and x <= 49 then
                        if inimigoAtual.isBoss then mensagemLog = "Nao fuja do CHEFE!"; tocar("bass", 3); atualizarTela(); os.sleep(1); turnoInimigo(); atualizarTela()
                        elseif math.random(1, 100) <= 60 then mensagemLog = "Fugiu!"; atualizarTela(); os.sleep(1); ESTADO = "MAPA"; atualizarTela()
                        else mensagemLog = "Falhou em fugir!"; atualizarTela(); os.sleep(1); turnoInimigo(); atualizarTela() end
                    end
                elseif ESTADO == "SUBMENU_ITEM" then
                    if x >= 4 and x <= 19 then
                        if jogador.pocoes > 0 then
                            jogador.pocoes = jogador.pocoes - 1; jogador.hp = math.min(jogador.maxHp, jogador.hp + 50)
                            mensagemLog = "Curou 50 HP!"; tocar("chime", 10); ESTADO = "BATALHA"; atualizarTela(); os.sleep(1); turnoInimigo(); atualizarTela()
                        else mensagemLog = "Sem pocoes!"; atualizarTela() end
                    elseif x >= 22 and x <= 37 then tentarCaptura()
                    elseif x >= 40 and x <= 49 then ESTADO = "BATALHA"; atualizarTela() end
                end
            end
        end
    end
end

local function escutarSaida()
    while rodando do
        local _, p1 = os.pullEvent("key")
        if p1 == keys.q then rodando = false; mon.setBackgroundColor(colors.black); mon.clear() end
    end
end

local sucesso, erro = pcall(function() parallel.waitForAny(escutarSaida, loopJogo, loopMusica) end)
if not sucesso then term.clear(); term.setCursorPos(1,1); print("ERRO DETECTADO:"); print(erro) end
