-- =======================================================
-- AETHERIA - MONSTER TAMER & INFINITE MAP
-- =======================================================
local mon = peripheral.find("monitor")
local listaSpeakers = {peripheral.find("speaker")}

local speakerSFX = listaSpeakers[1]
local speakerBGM = listaSpeakers[2] or listaSpeakers[1]

if not mon then print("[ERRO] Monitor nao encontrado!") return end

-- =======================================================
-- ESTADO GLOBAL E SAVE
-- =======================================================
local ESTADO = "MAPA" -- MAPA, BATALHA, GAMEOVER
local rodando = true
local volume = 0.8
local mensagemLog = "Explore o mundo!"

local jogador = { 
    x = 0, y = 0, -- Posicao no mundo infinito
    nivel = 1, xp = 0, hp = 100, maxHp = 100,
    ouro = 0, pocoes = 5,
    monstro = "Ignis (Fogo)"
}

local inimigoAtual = nil

-- Bestiario (Animais Elementais)
local bestiario = {
    {nome="Gota Selvagem", hp=30, dano=8, xp=10, ouro=5, cor=colors.lightBlue, arte={"  _  "," / \\ ","(o.o)"," --- "}},
    {nome="Espirito Folha", hp=40, dano=12, xp=15, ouro=8, cor=colors.lime, arte={" \\|/ ","-o.o-"," /|\\ "}},
    {nome="Pedra Viva", hp=60, dano=15, xp=20, ouro=15, cor=colors.gray, arte={" [ ] ","(o-o)"," [ ] "}},
    {nome="Lobo de Chamas", hp=80, dano=22, xp=35, ouro=25, cor=colors.orange, arte={" /\\/\\ ","( o.o)"," >^^< "}}
}

local chefes = {
    {nome="TITAN CRISTAL", hp=300, dano=35, xp=150, ouro=100, cor=colors.magenta, arte={" /\\/\\/\\ "," |O..O| "," |____| "," /\\/\\/\\ "}},
    {nome="DRAGAO CELESTE", hp=600, dano=50, xp=500, ouro=500, cor=colors.cyan, arte={" \\||||/ "," (O__O) "," /|  |\\ ","  |__|  "}}
}

-- =======================================================
-- SISTEMA DE AUDIO E BGM
-- =======================================================
local function tocar(som, pitch)
    if speakerSFX then pcall(function() speakerSFX.playSound(som, volume, pitch or 1.0) end) end
end

local function loopMusica()
    while rodando do
        if speakerBGM and (ESTADO == "MAPA" or ESTADO == "BATALHA") then
            -- Toca musica do Nether para uma vibe misteriosa de exploração
            pcall(function() speakerBGM.playSound("music_disc.pigstep", 2.0, 1.0) end)
        end
        os.sleep(145)
    end
end
tocar("entity.player.levelup", 2.0)

-- =======================================================
-- GERADOR DE MAPA INFINITO (MATEMÁTICO)
-- =======================================================
-- Gera um bloco especifico baseado nas coordenadas (X, Y)
local function getTile(gx, gy)
    if gx == 0 and gy == 0 then return colors.yellow end -- Spawn Seguro
    
    -- Hash simples para gerar mapa pseudo-aleatorio consistente
    local hash = math.abs((gx * 374761393) + (gy * 668265263)) % 100
    
    if hash < 2 then return colors.magenta end     -- 2%: Altar do Chefe (Magenta)
    if hash < 5 then return colors.cyan end        -- 3%: Cristal de Cura (Ciano)
    if hash < 20 then return colors.green end      -- 15%: Arvore/Parede (Verde Escuro)
    if hash < 60 then return colors.lime end       -- 40%: Grama Alta/Encontros (Verde Claro)
    return colors.lightGray                        -- 40%: Caminho de Terra (Cinza)
end

-- =======================================================
-- UTILITARIOS DE DESENHO (DRAWPIXEL E UI)
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
-- TELAS DO JOGO
-- =======================================================
local function desenharMapa()
    mon.setBackgroundColor(colors.black); mon.clear()
    local larg, alt = mon.getSize()
    local viewLarg = larg - 22 -- Area do mapa (esquerda)
    
    -- DESENHA O MAPA PROCEDURAL COM DRAWPIXEL
    local cx = math.floor(viewLarg / 2)
    local cy = math.floor(alt / 2)
    
    for screenY = 1, alt do
        for screenX = 1, viewLarg do
            local worldX = jogador.x + (screenX - cx)
            local worldY = jogador.y + (screenY - cy)
            local tileColor = getTile(worldX, worldY)
            
            -- Desenha o chao
            paintutils.drawPixel(screenX, screenY, tileColor)
            
            -- Desenha o Jogador no centro
            if screenX == cx and screenY == cy then
                mon.setCursorPos(screenX, screenY)
                mon.setTextColor(colors.white)
                mon.setBackgroundColor(tileColor)
                mon.write("@")
            end
        end
    end
    
    -- DESENHA O PAINEL LATERAL DIREITO (UI)
    local painelX = viewLarg + 1
    mon.setBackgroundColor(colors.gray)
    for i=1, alt do mon.setCursorPos(painelX, i); mon.write(string.rep(" ", 22)) end
    
    centralizar(painelX, 22, 2, "A E T H E R I A", colors.yellow, colors.gray)
    centralizar(painelX, 22, 4, jogador.monstro, colors.cyan, colors.gray)
    centralizar(painelX, 22, 5, string.format("Lvl:%d | XP:%d", jogador.nivel, jogador.xp), colors.white, colors.gray)
    
    -- Barra de HP no menu lateral
    mon.setCursorPos(painelX+1, 7); mon.setBackgroundColor(colors.black); mon.write(string.rep(" ", 20))
    local hpFill = math.floor((jogador.hp / jogador.maxHp) * 20)
    if hpFill > 0 then
        mon.setCursorPos(painelX+1, 7); mon.setBackgroundColor(colors.lime); mon.write(string.rep(" ", hpFill))
    end
    
    -- Mensagem do Log
    centralizar(painelX, 22, 9, mensagemLog, colors.orange, colors.gray)
    
    -- D-PAD (CONTROLES DE MOVIMENTO NA TELA)
    desenharBotao(painelX + 8, 12, 6, 2, "/\\", colors.lightGray, colors.black) -- CIMA
    desenharBotao(painelX + 2, 15, 6, 2, "<", colors.lightGray, colors.black)  -- ESQUERDA
    desenharBotao(painelX + 14, 15, 6, 2, ">", colors.lightGray, colors.black) -- DIREITA
    desenharBotao(painelX + 8, 18, 6, 2, "\\/", colors.lightGray, colors.black) -- BAIXO
end

local function desenharBatalha()
    mon.setBackgroundColor(colors.black); mon.clear()
    local larg, alt = mon.getSize()
    
    -- Cabecalho
    mon.setCursorPos(1, 1); mon.setBackgroundColor(colors.blue); mon.write(string.rep(" ", larg))
    centralizar(1, larg, 1, "BATALHA DE MONSTROS!", colors.white, colors.blue)

    -- Desenho do Inimigo
    if inimigoAtual then
        centralizar(1, larg, 4, inimigoAtual.nome, inimigoAtual.cor, colors.black)
        centralizar(1, larg, 5, "HP: " .. inimigoAtual.hp .. " / " .. inimigoAtual.maxHp, colors.red, colors.black)
        
        -- Desenha a Arte Pixelada (ASCII)
        for i, linha in ipairs(inimigoAtual.arte) do
            centralizar(1, larg, 6 + i, linha, inimigoAtual.cor, colors.black)
        end
    end

    -- Status do Jogador
    mon.setCursorPos(4, alt - 6); mon.setTextColor(colors.cyan); mon.write(jogador.monstro)
    mon.setCursorPos(4, alt - 5); mon.setTextColor(colors.white); mon.write(string.format("HP: %d / %d", jogador.hp, jogador.maxHp))
    
    -- Caixa de Log
    mon.setBackgroundColor(colors.gray)
    for i=0, 2 do mon.setCursorPos(24, alt-6+i); mon.write(string.rep(" ", larg-25)) end
    mon.setCursorPos(26, alt-5); mon.setTextColor(colors.white); mon.write(mensagemLog)

    mon.setBackgroundColor(colors.black)
    
    -- Botoes de Acao
    desenharBotao(4, alt - 2, 12, 2, "ATACAR", colors.red, colors.white)
    desenharBotao(18, alt - 2, 16, 2, "POCAO ("..jogador.pocoes..")", colors.lime, colors.black)
    desenharBotao(36, alt - 2, 12, 2, "FUGIR", colors.yellow, colors.black)
end

local function atualizarTela()
    mon.setTextScale(1)
    if ESTADO == "MAPA" then desenharMapa()
    elseif ESTADO == "BATALHA" then desenharBatalha()
    end
end

-- =======================================================
-- LOGICA DE MAPA E COMBATE
-- =======================================================
local function moverJogador(dx, dy)
    local nx = jogador.x + dx
    local ny = jogador.y + dy
    local tile = getTile(nx, ny)
    
    -- Colisão com árvores/paredes
    if tile == colors.green then
        mensagemLog = "Caminho bloqueado!"; tocar("block.wood.hit", 1); atualizarTela(); return
    end
    
    jogador.x = nx
    jogador.y = ny
    tocar("block.grass.step", 1)
    
    -- Interação com Tiles
    if tile == colors.cyan then
        -- CRISTAL DE CURA
        jogador.hp = jogador.maxHp
        jogador.pocoes = jogador.pocoes + 1
        mensagemLog = "Curado pelo Cristal!"
        tocar("entity.experience_orb.pickup", 1)
    
    elseif tile == colors.magenta then
        -- CHEFÃO
        local boss = chefes[math.min(jogador.nivel, #chefes)]
        local mult = 1.0 + (jogador.nivel * 0.5)
        inimigoAtual = {
            nome = boss.nome, maxHp = math.floor(boss.hp*mult), hp = math.floor(boss.hp*mult),
            dano = math.floor(boss.dano*mult), xp = math.floor(boss.xp*mult),
            cor = boss.cor, arte = boss.arte, isBoss = true
        }
        mensagemLog = "O CHEFE APARECEU!"
        tocar("entity.ender_dragon.growl", 1)
        ESTADO = "BATALHA"
        
    elseif tile == colors.lime then
        -- GRAMA ALTA (Encontros Aleatórios 20% de chance ao pisar)
        if math.random(1, 100) <= 20 then
            local monstro = bestiario[math.random(1, math.min(jogador.nivel + 1, #bestiario))]
            local mult = 1.0 + ((jogador.nivel - 1) * 0.2)
            inimigoAtual = {
                nome = monstro.nome, maxHp = math.floor(monstro.hp*mult), hp = math.floor(monstro.hp*mult),
                dano = math.floor(monstro.dano*mult), xp = math.floor(monstro.xp*mult),
                cor = monstro.cor, arte = monstro.arte, isBoss = false
            }
            mensagemLog = "Um " .. inimigoAtual.nome .. " selvagem surgiu!"
            tocar("entity.zombie.ambient", 1.5)
            ESTADO = "BATALHA"
        else
            mensagemLog = "Apenas grama alta."
        end
    else
        mensagemLog = "Explorando..."
    end
    
    atualizarTela()
end

local function turnoInimigo()
    if inimigoAtual and inimigoAtual.hp > 0 then
        local dano = math.random(math.floor(inimigoAtual.dano * 0.7), inimigoAtual.dano)
        jogador.hp = math.max(0, jogador.hp - dano)
        mensagemLog = inimigoAtual.nome .. " atacou! (-" .. dano .. " HP)"
        tocar("entity.player.hurt", 1)
        
        if jogador.hp <= 0 then
            jogador.hp = 0; mensagemLog = "SEU MONSTRO DESMAIOU. GAME OVER."; atualizarTela()
            tocar("entity.wither.death", 0.5); os.sleep(3)
            -- Revive na base
            jogador.x = 0; jogador.y = 0; jogador.hp = jogador.maxHp; ESTADO = "MAPA"; atualizarTela()
        end
    end
end

local function vitoria()
    tocar("entity.experience_orb.pickup", 1.5)
    jogador.xp = jogador.xp + inimigoAtual.xp
    mensagemLog = "Vitoria! +" .. inimigoAtual.xp .. " XP"
    atualizarTela(); os.sleep(1.5)
    
    if jogador.xp >= (jogador.nivel * 30) then
        jogador.xp = jogador.xp - (jogador.nivel * 30)
        jogador.nivel = jogador.nivel + 1
        jogador.maxHp = jogador.maxHp + 20
        jogador.hp = jogador.maxHp
        mensagemLog = "SEU MONSTRO SUBIU DE NIVEL!"
        tocar("entity.player.levelup", 1)
        atualizarTela(); os.sleep(2)
    end
    ESTADO = "MAPA"
    atualizarTela()
end

-- =======================================================
-- LOOP DE TOQUES E EVENTOS
-- =======================================================
local function loopJogo()
    atualizarTela()
    
    while rodando do
        local ev, _, x, y = os.pullEvent("monitor_touch")
        local larg, alt = mon.getSize()
        local painelX = (larg - 22) + 1
        
        if ESTADO == "MAPA" then
            -- Botoes do D-Pad
            if y >= 12 and y <= 13 and x >= painelX + 8 and x <= painelX + 13 then moverJogador(0, -1) -- CIMA
            elseif y >= 18 and y <= 19 and x >= painelX + 8 and x <= painelX + 13 then moverJogador(0, 1) -- BAIXO
            elseif y >= 15 and y <= 16 and x >= painelX + 2 and x <= painelX + 7 then moverJogador(-1, 0) -- ESQUERDA
            elseif y >= 15 and y <= 16 and x >= painelX + 14 and x <= painelX + 19 then moverJogador(1, 0) -- DIREITA
            end
            
        elseif ESTADO == "BATALHA" then
            if y >= alt - 2 and y <= alt - 1 then
                if x >= 4 and x <= 15 then
                    -- ATACAR
                    tocar("entity.player.attack.sweep", 1.2)
                    local dano = math.random(10 + (jogador.nivel*3), 15 + (jogador.nivel*5))
                    inimigoAtual.hp = inimigoAtual.hp - dano
                    mensagemLog = jogador.monstro .. " causou " .. dano .. " dano!"
                    atualizarTela(); os.sleep(1)
                    if inimigoAtual.hp <= 0 then vitoria() else turnoInimigo(); atualizarTela() end
                    
                elseif x >= 18 and x <= 33 then
                    -- POCAO
                    if jogador.pocoes > 0 then
                        jogador.pocoes = jogador.pocoes - 1
                        jogador.hp = math.min(jogador.maxHp, jogador.hp + 50)
                        mensagemLog = "Curou 50 HP!"
                        tocar("entity.generic.drink", 1)
                        atualizarTela(); os.sleep(1); turnoInimigo(); atualizarTela()
                    else
                        mensagemLog = "Sem pocoes!"; atualizarTela()
                    end
                    
                elseif x >= 36 and x <= 47 then
                    -- FUGIR
                    if inimigoAtual.isBoss then
                        mensagemLog = "Nao fuja do CHEFE!"
                        tocar("entity.villager.no", 1); atualizarTela(); os.sleep(1); turnoInimigo(); atualizarTela()
                    elseif math.random(1, 100) <= 60 then
                        mensagemLog = "Fugiu da batalha!"
                        atualizarTela(); os.sleep(1); ESTADO = "MAPA"; atualizarTela()
                    else
                        mensagemLog = "Falhou em fugir!"
                        atualizarTela(); os.sleep(1); turnoInimigo(); atualizarTela()
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

-- Iniciador Seguro
local sucesso, erro = pcall(function() parallel.waitForAny(escutarSaida, loopJogo, loopMusica) end)
if not sucesso then
    term.clear(); term.setCursorPos(1,1); print("ERRO DETECTADO:")
    print(erro)
end
