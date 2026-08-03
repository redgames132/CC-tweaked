-- =======================================================
-- AETHERIA 3.0 - PALETA CUSTOMIZADA E SOM NATIVO 1.21.1
-- =======================================================
local mon = peripheral.find("monitor")
local listaSpeakers = {peripheral.find("speaker")}

local speakerSFX = listaSpeakers[1]
local speakerBGM = listaSpeakers[2] or listaSpeakers[1]

if not mon then print("[ERRO] Monitor nao encontrado!") return end

-- =======================================================
-- REPROGRAMAÇÃO DA PLACA DE VÍDEO (CORES PASTEL)
-- =======================================================
-- Isso deixa os graficos incriveis e suaves, tirando o neon do Minecraft
mon.setPaletteColor(colors.lime, 0x8bbf54)       -- Grama base
mon.setPaletteColor(colors.green, 0x5a8a32)      -- Grama Alta (Encontros)
mon.setPaletteColor(colors.blue, 0x4a9cc2)       -- Agua
mon.setPaletteColor(colors.lightBlue, 0x82c8e5)  -- Detalhe da agua
mon.setPaletteColor(colors.gray, 0x737a80)       -- Montanhas
mon.setPaletteColor(colors.lightGray, 0x9ca3a8)  -- Detalhe montanha
mon.setPaletteColor(colors.yellow, 0xf2c94c)     -- UI e Ouro
mon.setPaletteColor(colors.red, 0xe05656)        -- Botoes e Inimigos de Fogo
mon.setPaletteColor(colors.cyan, 0x47e8cd)       -- Cristais Magicos

local ESTADO = "MENU"
local rodando = true
local volume = 1.0
local mensagemLog = "Bem-vindo a Aetheria!"

local jogador = { 
    x = 0, y = 0, nivel = 1, xp = 0, hp = 100, maxHp = 100,
    ouro = 0, pocoes = 5, monstro = "Nenhum", tipo = "Normal"
}
local inimigoAtual = nil

local bestiario = {
    {nome="Gota Selvagem", tipo="Agua", hp=40, dano=10, xp=15, ouro=5, cor=colors.blue, arte={"  _  "," / \\ ","(o.o)"," --- "}},
    {nome="Espirito Folha", tipo="Planta", hp=45, dano=12, xp=15, ouro=8, cor=colors.green, arte={" \\|/ ","-o.o-"," /|\\ ","     "}},
    {nome="Lobo de Chamas", tipo="Fogo", hp=60, dano=18, xp=25, ouro=15, cor=colors.red, arte={" /\\/\\ ","( o.o)"," >^^< ","      "}},
    {nome="Tartaruga Rio", tipo="Agua", hp=80, dano=14, xp=30, ouro=20, cor=colors.blue, arte={"  ___  "," /o o\\ ","(_____)","       "}},
    {nome="Tronco Vivo", tipo="Planta", hp=90, dano=20, xp=40, ouro=25, cor=colors.brown, arte={" [~~~] "," [o.o] "," /[ ]\\ ","       "}}
}

local chefes = {
    {nome="TITAN DE GELO", tipo="Agua", hp=300, dano=30, xp=200, ouro=150, cor=colors.cyan, arte={" /\\/\\/\\ "," |O..O| "," |____| "," /\\/\\/\\ "}},
    {nome="DRAGAO CELESTE", tipo="Fogo", hp=600, dano=55, xp=500, ouro=500, cor=colors.red, arte={" \\||||/ "," (O__O) "," /|  |\\ ","  |__|  "}}
}

-- =======================================================
-- MOTOR DE AUDIO NATIVO 1.21.1 (CC 1.120)
-- =======================================================
local function tocar(instrumento, pitch)
    -- Usa playNote que é nativo e nao sofre com mudancas de registro do Minecraft
    if speakerSFX then pcall(function() speakerSFX.playNote(instrumento, volume, pitch) end) end
end

-- As notas vao de 0 a 24 em playNote
local melodia = {
    {12, 0.20}, {16, 0.20}, {19, 0.20}, {16, 0.20},
    {12, 0.20}, {16, 0.20}, {19, 0.40},
    {14, 0.20}, {17, 0.20}, {21, 0.20}, {17, 0.20},
    {14, 0.20}, {17, 0.20}, {21, 0.40},
    {10, 0.20}, {14, 0.20}, {17, 0.20}, {14, 0.20},
    {10, 0.20}, {14, 0.20}, {17, 0.40},
    {12, 0.20}, {16, 0.20}, {19, 0.20}, {24, 0.20},
    {19, 0.20}, {16, 0.20}, {12, 0.50}
}

local function loopMusica()
    local idx = 1
    while rodando do
        if speakerBGM and (ESTADO == "MAPA" or ESTADO == "BATALHA" or ESTADO == "LOJA") then
            local nota = melodia[idx]
            -- O instrumento "harp" é universal e perfeito para o 8-bit
            pcall(function() speakerBGM.playNote("harp", volume * 0.5, nota[1]) end)
            idx = (idx % #melodia) + 1
            os.sleep(nota[2])
        else
            os.sleep(0.5)
        end
    end
end

-- Toca um som inicial para confirmar que o speakerSFX esta vivo
tocar("chime", 12)

-- =======================================================
-- GERADOR DE BIOMAS COM TEXTURAS
-- =======================================================
local function getTile(wx, wy)
    if wx >= -1 and wx <= 1 and wy >= -1 and wy <= 1 then return {bg=colors.yellow, fg=colors.white, char="*", type="spawn"} end
    
    local hash = math.abs((wx * 1337) + (wy * 99991)) % 1000
    if hash < 5 then return {bg=colors.magenta, fg=colors.white, char="H", type="chefe"} end
    if hash < 20 then return {bg=colors.cyan, fg=colors.white, char="+", type="cura"} end
    
    local ruido = math.sin(wx * 0.3) + math.cos(wy * 0.3) + math.sin((wx+wy) * 0.1)
    
    if ruido < -1.0 then return {bg=colors.blue, fg=colors.lightBlue, char="~", type="agua"} end
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
-- RENDERIZADOR DE TELAS
-- =======================================================
local function desenharMenu()
    mon.setBackgroundColor(colors.black); mon.clear()
    local larg, alt = mon.getSize()
    centralizar(1, larg, 4, "A E T H E R I A", colors.yellow, colors.black)
    centralizar(1, larg, 6, "Domadores de Monstros", colors.cyan, colors.black)
    desenharBotao(math.floor(larg/2)-10, 10, 20, 3, "INICIAR JORNADA", colors.lime, colors.white)
end

local function desenharEscolha()
    mon.setBackgroundColor(colors.black); mon.clear()
    local larg, alt = mon.getSize()
    centralizar(1, larg, 3, "ESCOLHA SEU AETHER INICIAL", colors.white, colors.black)
    
    desenharBotao(math.floor(larg/2)-25, 8, 14, 3, "IGNIS (FOGO)", colors.red, colors.white)
    desenharBotao(math.floor(larg/2)-7, 8, 14, 3, "AQUA (AGUA)", colors.blue, colors.white)
    desenharBotao(math.floor(larg/2)+11, 8, 15, 3, "FLORA (PLANTA)", colors.green, colors.white)
end

local function desenharMapa()
    mon.setBackgroundColor(colors.black); mon.clear()
    local larg, alt = mon.getSize()
    local viewLarg = larg - 24 
    
    local cx = math.floor(viewLarg / 2)
    local cy = math.floor(alt / 2)
    
    -- Desenha o mapa texturizado
    for screenY = 1, alt do
        for screenX = 1, viewLarg do
            local worldX = jogador.x + (screenX - cx)
            local worldY = jogador.y + (screenY - cy)
            local tile = getTile(worldX, worldY)
            
            mon.setCursorPos(screenX, screenY)
            mon.setBackgroundColor(tile.bg)
            
            if screenX == cx and screenY == cy then
                mon.setTextColor(colors.white)
                mon.write("@")
            else
                mon.setTextColor(tile.fg)
                mon.write(tile.char)
            end
        end
    end
    
    -- UI Lateral Dark Mode
    local painelX = viewLarg + 1
    mon.setBackgroundColor(colors.black)
    for i=1, alt do mon.setCursorPos(painelX, i); mon.write(string.rep(" ", 24)) end
    
    -- Borda do Menu
    mon.setBackgroundColor(colors.gray)
    for i=1, alt do mon.setCursorPos(painelX, i); mon.write(" ") end
    
    centralizar(painelX+1, 23, 2, "A E T H E R I A", colors.yellow, colors.black)
    centralizar(painelX+1, 23, 4, jogador.monstro .. " ("..jogador.tipo..")", colors.cyan, colors.black)
    centralizar(painelX+1, 23, 5, string.format("Lvl:%d | XP:%d", jogador.nivel, jogador.xp), colors.white, colors.black)
    
    mon.setCursorPos(painelX+2, 7); mon.setBackgroundColor(colors.gray); mon.write(string.rep(" ", 20))
    local hpFill = math.floor((jogador.hp / jogador.maxHp) * 20)
    if hpFill > 0 then
        mon.setCursorPos(painelX+2, 7); mon.setBackgroundColor(colors.lime); mon.write(string.rep(" ", hpFill))
    end
    mon.setBackgroundColor(colors.black)
    
    centralizar(painelX+1, 23, 9, mensagemLog, colors.yellow, colors.black)
    
    -- D-PAD Moderno
    desenharBotao(painelX + 9, 12, 6, 2, "/\\", colors.gray, colors.white)
    desenharBotao(painelX + 2, 15, 6, 2, "<", colors.gray, colors.white)
    desenharBotao(painelX + 16, 15, 6, 2, ">", colors.gray, colors.white)
    desenharBotao(painelX + 9, 18, 6, 2, "\\/", colors.gray, colors.white)
end

local function desenharBatalha()
    mon.setBackgroundColor(colors.black); mon.clear()
    local larg, alt = mon.getSize()
    
    mon.setCursorPos(1, 1); mon.setBackgroundColor(colors.yellow); mon.write(string.rep(" ", larg))
    centralizar(1, larg, 1, "BATALHA: " .. jogador.monstro .. " VS " .. inimigoAtual.nome, colors.black, colors.yellow)

    if inimigoAtual then
        centralizar(1, larg, 4, inimigoAtual.nome .. " (" .. inimigoAtual.tipo .. ")", inimigoAtual.cor, colors.black)
        centralizar(1, larg, 5, "HP: " .. inimigoAtual.hp .. " / " .. inimigoAtual.maxHp, colors.red, colors.black)
        for i, linha in ipairs(inimigoAtual.arte) do
            centralizar(1, larg, 6 + i, linha, inimigoAtual.cor, colors.black)
        end
    end

    mon.setCursorPos(4, alt - 6); mon.setTextColor(colors.cyan); mon.setBackgroundColor(colors.black); mon.write(jogador.monstro .. " ("..jogador.tipo..")")
    mon.setCursorPos(4, alt - 5); mon.setTextColor(colors.white); mon.write(string.format("HP: %d / %d", jogador.hp, jogador.maxHp))
    
    mon.setBackgroundColor(colors.gray)
    for i=0, 2 do mon.setCursorPos(24, alt-6+i); mon.write(string.rep(" ", larg-25)) end
    mon.setCursorPos(26, alt-5); mon.setTextColor(colors.white); mon.write(mensagemLog)

    mon.setBackgroundColor(colors.black)
    desenharBotao(4, alt - 2, 14, 2, "ATACAR", colors.red, colors.white)
    desenharBotao(20, alt - 2, 16, 2, "CURAR ("..jogador.pocoes..")", colors.lime, colors.black)
    desenharBotao(38, alt - 2, 12, 2, "FUGIR", colors.yellow, colors.black)
end

local function atualizarTela()
    mon.setTextScale(1)
    if ESTADO == "MENU" then desenharMenu()
    elseif ESTADO == "ESCOLHA" then desenharEscolha()
    elseif ESTADO == "MAPA" then desenharMapa()
    elseif ESTADO == "BATALHA" then desenharBatalha()
    end
end

-- =======================================================
-- LOGICA DE COMBATE
-- =======================================================
local function moverJogador(dx, dy)
    local nx = jogador.x + dx
    local ny = jogador.y + dy
    local tile = getTile(nx, ny)
    
    if tile.type == "agua" or tile.type == "montanha" then
        mensagemLog = "Caminho bloqueado!"; tocar("bass", 5); atualizarTela(); return
    end
    
    jogador.x = nx; jogador.y = ny; tocar("hat", 12)
    
    if tile.type == "cura" then
        jogador.hp = jogador.maxHp; jogador.pocoes = jogador.pocoes + 1
        mensagemLog = "Curado pelo Cristal!"; tocar("chime", 15)
        
    elseif tile.type == "chefe" then
        local boss = chefes[math.random(1, #chefes)]
        local mult = 1.0 + (jogador.nivel * 0.2)
        inimigoAtual = {nome=boss.nome, tipo=boss.tipo, maxHp=math.floor(boss.hp*mult), hp=math.floor(boss.hp*mult), dano=math.floor(boss.dano*mult), xp=boss.xp, cor=boss.cor, arte=boss.arte, isBoss=true}
        mensagemLog = "O CHEFE APARECEU!"; tocar("bass", 2); ESTADO = "BATALHA"
        
    elseif tile.type == "grama_alta" then
        if math.random(1, 100) <= 20 then
            local maxId = math.min(jogador.nivel + 1, #bestiario)
            local monstro = bestiario[math.random(1, maxId)]
            local mult = 1.0 + ((jogador.nivel - 1) * 0.15)
            inimigoAtual = {nome=monstro.nome, tipo=monstro.tipo, maxHp=math.floor(monstro.hp*mult), hp=math.floor(monstro.hp*mult), dano=math.floor(monstro.dano*mult), xp=math.floor(monstro.xp*mult), cor=monstro.cor, arte=monstro.arte, isBoss=false}
            mensagemLog = "Selvagem surgiu!"; tocar("cow_bell", 10); ESTADO = "BATALHA"
        else
            mensagemLog = "Grama alta..."
        end
    else
        mensagemLog = "Explorando..."
    end
    atualizarTela()
end

local function turnoInimigo()
    if inimigoAtual and inimigoAtual.hp > 0 then
        local dano = math.random(math.floor(inimigoAtual.dano * 0.7), inimigoAtual.dano)
        
        local mult = 1
        if inimigoAtual.tipo == "Fogo" and jogador.tipo == "Planta" then mult = 1.5 end
        if inimigoAtual.tipo == "Planta" and jogador.tipo == "Agua" then mult = 1.5 end
        if inimigoAtual.tipo == "Agua" and jogador.tipo == "Fogo" then mult = 1.5 end
        if mult > 1 then mensagemLog = "SUPER EFETIVO! " end
        
        dano = math.floor(dano * mult)
        jogador.hp = math.max(0, jogador.hp - dano)
        mensagemLog = mensagemLog .. inimigoAtual.nome .. " atacou!"
        tocar("snare", 5)
        
        if jogador.hp <= 0 then
            jogador.hp = 0; mensagemLog = "DESMAIOU! Fim da linha."; atualizarTela()
            tocar("bass", 1); os.sleep(3)
            jogador.x = 0; jogador.y = 0; jogador.hp = jogador.maxHp; ESTADO = "MAPA"; atualizarTela()
        end
    end
end

local function vitoria()
    tocar("chime", 18)
    jogador.xp = jogador.xp + inimigoAtual.xp
    mensagemLog = "Vitoria! +" .. inimigoAtual.xp .. " XP"
    atualizarTela(); os.sleep(1.5)
    
    if jogador.xp >= (jogador.nivel * 30) then
        jogador.xp = jogador.xp - (jogador.nivel * 30)
        jogador.nivel = jogador.nivel + 1
        jogador.maxHp = jogador.maxHp + 15; jogador.hp = jogador.maxHp
        mensagemLog = "MONSTRO SUBIU DE NIVEL!"
        tocar("chime", 24); atualizarTela(); os.sleep(2)
    end
    ESTADO = "MAPA"; atualizarTela()
end

-- =======================================================
-- INPUTS DO JOGADOR
-- =======================================================
local function loopJogo()
    atualizarTela()
    
    while rodando do
        local ev, _, x, y = os.pullEvent("monitor_touch")
        local larg, alt = mon.getSize()
        local painelX = (larg - 24) + 1
        
        if ESTADO == "MENU" then
            if y >= 10 and y <= 12 then ESTADO = "ESCOLHA"; atualizarTela() end
            
        elseif ESTADO == "ESCOLHA" then
            if y >= 8 and y <= 10 then
                if x >= math.floor(larg/2)-25 and x <= math.floor(larg/2)-11 then
                    jogador.monstro = "Ignis"; jogador.tipo = "Fogo"
                elseif x >= math.floor(larg/2)-7 and x <= math.floor(larg/2)+7 then
                    jogador.monstro = "Aqua"; jogador.tipo = "Agua"
                elseif x >= math.floor(larg/2)+11 and x <= math.floor(larg/2)+26 then
                    jogador.monstro = "Flora"; jogador.tipo = "Planta"
                end
                if jogador.monstro ~= "Nenhum" then tocar("chime", 12); ESTADO = "MAPA"; atualizarTela() end
            end
            
        elseif ESTADO == "MAPA" then
            if y >= 12 and y <= 13 and x >= painelX + 9 and x <= painelX + 14 then moverJogador(0, -1)
            elseif y >= 18 and y <= 19 and x >= painelX + 9 and x <= painelX + 14 then moverJogador(0, 1)
            elseif y >= 15 and y <= 16 and x >= painelX + 2 and x <= painelX + 7 then moverJogador(-1, 0)
            elseif y >= 15 and y <= 16 and x >= painelX + 16 and x <= painelX + 21 then moverJogador(1, 0)
            end
            
        elseif ESTADO == "BATALHA" then
            if y >= alt - 2 and y <= alt - 1 then
                if x >= 4 and x <= 17 then
                    tocar("snare", 15)
                    local dano = math.random(10 + (jogador.nivel*3), 15 + (jogador.nivel*5))
                    
                    local mult = 1
                    if jogador.tipo == "Fogo" and inimigoAtual.tipo == "Planta" then mult = 1.5 end
                    if jogador.tipo == "Planta" and inimigoAtual.tipo == "Agua" then mult = 1.5 end
                    if jogador.tipo == "Agua" and inimigoAtual.tipo == "Fogo" then mult = 1.5 end
                    
                    if mult > 1 then mensagemLog = "SUPER EFETIVO! " else mensagemLog = "" end
                    dano = math.floor(dano * mult)
                    
                    inimigoAtual.hp = inimigoAtual.hp - dano
                    mensagemLog = mensagemLog .. "Causou " .. dano .. " dano!"
                    atualizarTela(); os.sleep(1)
                    if inimigoAtual.hp <= 0 then vitoria() else turnoInimigo(); atualizarTela() end
                    
                elseif x >= 20 and x <= 35 then
                    if jogador.pocoes > 0 then
                        jogador.pocoes = jogador.pocoes - 1; jogador.hp = math.min(jogador.maxHp, jogador.hp + 50)
                        mensagemLog = "Curou 50 HP!"; tocar("chime", 10)
                        atualizarTela(); os.sleep(1); turnoInimigo(); atualizarTela()
                    else mensagemLog = "Sem pocoes!"; atualizarTela() end
                    
                elseif x >= 38 and x <= 49 then
                    if inimigoAtual.isBoss then
                        mensagemLog = "Nao fuja do CHEFE!"; tocar("bass", 3); atualizarTela(); os.sleep(1); turnoInimigo(); atualizarTela()
                    elseif math.random(1, 100) <= 60 then
                        mensagemLog = "Fugiu!"; atualizarTela(); os.sleep(1); ESTADO = "MAPA"; atualizarTela()
                    else
                        mensagemLog = "Falhou em fugir!"; atualizarTela(); os.sleep(1); turnoInimigo(); atualizarTela()
                    end
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
