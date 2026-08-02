-- =======================================================
-- ⚙️ SETUP E PERIFÉRICOS
-- =======================================================
local mon = peripheral.find("monitor")
local speaker = peripheral.find("speaker")

if not mon then 
    print("❌ Erro: Monitor nao encontrado!") 
    return 
end

-- =======================================================
-- 📊 ESTADO GLOBAL DO JOGO E SAVE
-- =======================================================
local ESTADO = "MENU"
local estadoAnterior = "MENU"
local dificuldade = 1.0
local difNome = "NORMAL"
local volume = 0.5
local mensagemLog = ""
local mensagemLoja = ""
local rodando = true

local jogador = { 
    hp = 50, maxHp = 50, level = 1, xp = 0, 
    ouro = 0, pocoes = 3, pocoesMax = 0, 
    danoExtra = 0, defesa = 0 
}

local inimigoAtual = nil
local eventoAtual = nil

math.randomseed(os.time())

-- SISTEMA DE SAVE
local ARQUIVO_SAVE = "pilgramo_save.json"

local function salvarJogo()
    local f = fs.open(ARQUIVO_SAVE, "w")
    f.write(textutils.serialize(jogador))
    f.close()
end

local function carregarJogo()
    if fs.exists(ARQUIVO_SAVE) then
        local f = fs.open(ARQUIVO_SAVE, "r")
        local dados = f.readAll()
        f.close()
        if dados then
            jogador = textutils.unserialize(dados)
            -- Garante compatibilidade se o save for antigo
            jogador.defesa = jogador.defesa or 0
            jogador.pocoesMax = jogador.pocoesMax or 0
            return true
        end
    end
    return false
end

-- =======================================================
-- 🎵 SISTEMA DE ÁUDIO E BGM
-- =======================================================
local function tocar(som, pitch)
    if speaker then pcall(function() speaker.playSound(som, volume, pitch or 1.0) end) end
end

local function loopMusica()
    while rodando do
        -- Toca a música de fundo do Minecraft (dura alguns minutos)
        if speaker and (ESTADO == "MENU" or ESTADO == "BATALHA" or ESTADO == "LOJA") then
            pcall(function() speaker.playSound("music.game", volume * 0.5, 1.0) end)
        end
        -- Espera 2 minutos para tentar tocar de novo
        os.sleep(120)
    end
end

-- =======================================================
-- 👾 BESTIÁRIO, DROPS E EVENTOS
-- =======================================================
local bestiario = {
    {nome = "Slime de Musgo", maxHp = 15, dano = 4, xp = 5, ouro = 5, cor = colors.lime, arte = {"       ", "  ___  ", " (o.o) ", " (___) "}},
    {nome = "Lobo Selvagem", maxHp = 22, dano = 6, xp = 10, ouro = 8, cor = colors.lightGray, arte = {"       ", " / \\__ ", " (o.o )", "  / /  "}},
    {nome = "Goblin Ladrao", maxHp = 30, dano = 8, xp = 15, ouro = 15, cor = colors.green, arte = {"  ^ ^  ", " (O.O) ", " / | \\ ", "  / \\  "}},
    {nome = "Golem de Pedra", maxHp = 50, dano = 10, xp = 25, ouro = 18, cor = colors.gray, arte = {" [___] ", " [O.O] ", " /[|]\\ ", "  [ ]  "}},
    {nome = "Esqueleto Negro", maxHp = 60, dano = 14, xp = 35, ouro = 25, cor = colors.white, arte = {"  .-.  ", " (o o) ", "  |O|  ", " /| |\\ "}},
    {nome = "Vampiro Anciao", maxHp = 85, dano = 20, xp = 50, ouro = 45, cor = colors.red, arte = {"  _|_  ", " (v v) ", " /| |\\ ", "  / \\  "}},
    {nome = "Rei Demonio", maxHp = 150, dano = 30, xp = 100, ouro = 100, cor = colors.purple, arte = {" \\\\ // ", " (O O) ", " /| |\\ ", "  |_|  "}}
}

local eventos = {
    {nome = "Fonte Sagrada", desc = "Voce bebeu a agua e recuperou a vida!", cor = colors.lightBlue,
     acao = function() jogador.hp = jogador.maxHp; tocar("entity.player.levelup", 0.5) end},
    {nome = "Bau Escondido", desc = "Voce encontrou um bau cheio de moedas!", cor = colors.yellow,
     acao = function() jogador.ouro = jogador.ouro + 30; tocar("entity.experience_orb.pickup", 1) end},
    {nome = "Armadilha de Espinhos", desc = "Voce pisou em falso e tomou dano!", cor = colors.red,
     acao = function()
        jogador.hp = jogador.hp - 15; tocar("entity.player.hurt", 1)
        if jogador.hp <= 0 then jogador.hp = 0; ESTADO = "GAMEOVER"; tocar("entity.wither.death", 0.5) end
     end},
    {nome = "Fada da Floresta", desc = "Ela abencoou sua jornada (+10 Max HP)!", cor = colors.magenta,
     acao = function() jogador.maxHp = jogador.maxHp + 10; jogador.hp = jogador.maxHp; tocar("entity.player.levelup", 1.2) end}
}

-- =======================================================
-- 🎨 UTILITÁRIOS VISUAIS E UI MELHORADA
-- =======================================================
local function centralizar(y, texto, corTexto, corFundo)
    local larg, _ = mon.getSize()
    local x = math.floor((larg - #texto) / 2) + 1
    mon.setCursorPos(math.max(1, x), y)
    mon.setTextColor(corTexto or colors.white)
    if corFundo then mon.setBackgroundColor(corFundo) end
    mon.write(texto)
end

local function desenharCaixa(x, y, larg, alt, corFundo)
    mon.setBackgroundColor(corFundo)
    for i = 0, alt - 1 do
        mon.setCursorPos(x, y + i)
        mon.write(string.rep(" ", larg))
    end
end

local function desenharBotao(x, y, larg, texto, corFundo, corTexto)
    desenharCaixa(x, y, larg, 3, corFundo)
    mon.setCursorPos(x + math.floor((larg - #texto)/2), y + 1)
    mon.setTextColor(corTexto)
    mon.write(texto)
end

local function desenharMoldura()
    local larg, alt = mon.getSize()
    mon.setBackgroundColor(colors.gray)
    mon.setTextColor(colors.lightGray)
    -- Topo e Base
    mon.setCursorPos(1, 1)
    mon.write(string.rep("=", larg))
    mon.setCursorPos(1, alt)
    mon.write(string.rep("=", larg))
end

-- =======================================================
-- 🖥️ TELAS DO JOGO
-- =======================================================
local function desenharMenu()
    mon.setBackgroundColor(colors.black)
    mon.clear()
    desenharMoldura()
    local larg, _ = mon.getSize()
    
    centralizar(3, " ⚔️ P I L G R A M O ⚔️ ", colors.yellow, colors.black)
    centralizar(5, "O RPG de Computador", colors.lightGray, colors.black)
    
    local temSave = fs.exists(ARQUIVO_SAVE)
    if temSave then
        desenharBotao(math.floor(larg/2) - 10, 7, 20, "CONTINUAR JOGO", colors.cyan, colors.black)
        desenharBotao(math.floor(larg/2) - 10, 11, 20, "NOVO JOGO", colors.lime, colors.black)
    else
        desenharBotao(math.floor(larg/2) - 10, 9, 20, "NOVO JOGO", colors.lime, colors.black)
    end
    
    desenharBotao(math.floor(larg/2) - 10, temSave and 15 or 14, 20, "CONFIGURACOES", colors.blue, colors.white)
end

local function desenharLoja()
    mon.setBackgroundColor(colors.black)
    mon.clear()
    desenharMoldura()
    local larg, _ = mon.getSize()
    
    centralizar(2, " 🛒 MERCADOR DA ESTRADA 🛒 ", colors.yellow, colors.black)
    centralizar(4, "Seu Ouro: " .. jogador.ouro .. " | Defesa: " .. jogador.defesa .. " | Dano Extra: +" .. jogador.danoExtra, colors.lime, colors.black)
    
    if mensagemLoja ~= "" then centralizar(5, mensagemLoja, colors.cyan, colors.black) end
    
    -- 6 Itens na Loja
    desenharBotao(2, 7, 26, "POCAO (+25HP) - 15 Ouro", colors.gray, colors.white)
    desenharBotao(30, 7, 26, "SUPER POCAO (+50HP) - 30", colors.gray, colors.white)
    
    desenharBotao(2, 11, 26, "ESPADA (+5 Dano) - 40", colors.gray, colors.white)
    desenharBotao(30, 11, 26, "ESCUDO (+2 Defesa) - 40", colors.gray, colors.white)
    
    desenharBotao(2, 15, 26, "ARMADURA (+20 MaxHP) - 50", colors.gray, colors.white)
    desenharBotao(30, 15, 26, "ELIXIR (+30 XP) - 60", colors.gray, colors.white)
    
    desenharBotao(math.floor(larg/2) - 10, 19, 20, "VOLTAR AO JOGO", colors.blue, colors.white)
end

local function desenharBatalha()
    mon.setBackgroundColor(colors.black)
    mon.clear()
    local larg, _ = mon.getSize()
    
    -- Status Bar Superior
    mon.setCursorPos(1, 1)
    mon.setBackgroundColor(colors.blue)
    mon.write(string.rep(" ", larg))
    local txtStatus = string.format(" HP:%d/%d | LVL:%d | XP:%d | OURO:%d | DEF:%d ", jogador.hp, jogador.maxHp, jogador.level, jogador.xp, jogador.ouro, jogador.defesa)
    mon.setCursorPos(2, 1)
    mon.setTextColor(colors.white)
    mon.write(txtStatus)
    
    mon.setCursorPos(larg - 5, 1)
    mon.setBackgroundColor(colors.red)
    mon.write(" [||] ")

    -- Inimigo
    desenharCaixa(2, 3, 20, 9, colors.gray)
    if inimigoAtual then
        mon.setCursorPos(3, 4)
        mon.setTextColor(inimigoAtual.cor)
        mon.setBackgroundColor(colors.gray)
        mon.write(inimigoAtual.nome)
        
        mon.setCursorPos(3, 5)
        mon.setTextColor(colors.red)
        mon.write("HP: " .. inimigoAtual.hp .. "/" .. inimigoAtual.maxHp)
        
        for i, linha in ipairs(inimigoAtual.arte) do
            mon.setCursorPos(8, 6 + i)
            mon.setTextColor(inimigoAtual.cor)
            mon.write(linha)
        end
    end

    -- Diario de Batalha
    desenharCaixa(24, 3, larg - 25, 9, colors.black)
    mon.setCursorPos(24, 3)
    mon.setTextColor(colors.yellow)
    mon.setBackgroundColor(colors.black)
    mon.write(">> DIARIO DO PILGRAMO:")
    mon.setCursorPos(24, 5)
    mon.setTextColor(colors.white)
    mon.write(mensagemLog)

    -- Botoes
    desenharBotao(2, 14, 11, "ATACAR", colors.red, colors.white)
    desenharBotao(14, 14, 13, "CURA (" .. jogador.pocoes .. ")", colors.lime, colors.black)
    desenharBotao(28, 14, 11, "LOJA", colors.yellow, colors.black)
    desenharBotao(40, 14, 11, "FUGIR", colors.orange, colors.white)
end

local function atualizarTela()
    mon.setTextScale(1)
    if ESTADO == "MENU" then desenharMenu()
    elseif ESTADO == "LOJA" then desenharLoja()
    elseif ESTADO == "BATALHA" then desenharBatalha()
    -- Outras telas simplificadas no background para o tamanho do código
    end
end

-- =======================================================
-- ⚔️ LÓGICA DE COMBATE E DROPS
-- =======================================================
local function resetarJogador()
    jogador = { hp = 50, maxHp = 50, level = 1, xp = 0, ouro = 0, pocoes = 3, pocoesMax = 0, danoExtra = 0, defesa = 0 }
end

local function gerarEncontro()
    salvarJogo() -- Salva automaticamente a cada encontro!
    
    if math.random(1, 5) == 1 then
        eventoAtual = eventos[math.random(1, #eventos)]
        ESTADO = "BATALHA"
        mensagemLog = "Evento: " .. eventoAtual.desc
        eventoAtual.acao()
        inimigoAtual = nil
    else
        local maxIndex = math.min(jogador.level, #bestiario)
        local template = bestiario[math.random(1, maxIndex)]
        local vidaCalculada = math.floor(template.maxHp * dificuldade)
        inimigoAtual = {
            nome = template.nome, maxHp = vidaCalculada, hp = vidaCalculada,
            dano = math.floor(template.dano * dificuldade), xp = template.xp,
            ouro = template.ouro, cor = template.cor, arte = template.arte
        }
        mensagemLog = "Um " .. inimigoAtual.nome .. " selvagem surgiu!"
        ESTADO = "BATALHA"
        tocar("entity.zombie.ambient", 0.8)
    end
    atualizarTela()
end

local function turnoInimigo()
    if inimigoAtual and inimigoAtual.hp > 0 then
        -- Calcula defesa
        local dano = math.random(math.floor(inimigoAtual.dano / 2), inimigoAtual.dano)
        local danoReal = math.max(1, dano - jogador.defesa) -- Defesa reduz o dano (mínimo 1)
        
        jogador.hp = jogador.hp - danoReal
        mensagemLog = inimigoAtual.nome .. " atacou! (-" .. danoReal .. " HP)"
        tocar("entity.player.hurt", 1)
        
        if jogador.hp <= 0 then
            jogador.hp = 0; ESTADO = "MENU"; fs.delete(ARQUIVO_SAVE) -- Deleta save se morrer!
            tocar("entity.wither.death", 0.5)
        end
    end
end

local function processarCombate()
    if not inimigoAtual then gerarEncontro(); return end
    
    tocar("entity.player.attack.sweep", 1.2)
    local danoTotal = math.random(5 + (jogador.level * 2), 10 + (jogador.level * 3)) + jogador.danoExtra
    inimigoAtual.hp = inimigoAtual.hp - danoTotal
    
    if inimigoAtual.hp <= 0 then
        mensagemLog = "Derrotou " .. inimigoAtual.nome .. "! (+" .. inimigoAtual.xp .. "XP)"
        jogador.xp = jogador.xp + inimigoAtual.xp
        jogador.ouro = jogador.ouro + inimigoAtual.ouro
        tocar("entity.experience_orb.pickup", 1.5)
        
        -- SISTEMA DE DROPS
        local chance = math.random(1, 100)
        if chance <= 25 then
            jogador.pocoes = jogador.pocoes + 1
            mensagemLog = mensagemLog .. " | Drop: Pocao"
        elseif chance <= 35 then
            jogador.danoExtra = jogador.danoExtra + 1
            mensagemLog = mensagemLog .. " | Drop: Runa Forca (+1)"
            tocar("block.amethyst_block.chime", 1)
        elseif chance <= 45 then
            jogador.defesa = jogador.defesa + 1
            mensagemLog = mensagemLog .. " | Drop: Escama (+1 Def)"
            tocar("item.shield.block", 1)
        end
        
        atualizarTela(); os.sleep(1.5)
        
        local xpNecessario = jogador.level * 20
        if jogador.xp >= xpNecessario then
            jogador.level = jogador.level + 1
            jogador.xp = jogador.xp - xpNecessario
            jogador.maxHp = jogador.maxHp + 10; jogador.hp = jogador.maxHp
            mensagemLog = "LEVEL UP! HP Restaurado."
            tocar("ui.toast.challenge_complete", 1)
            atualizarTela(); os.sleep(1.5)
        end
        gerarEncontro()
    else
        mensagemLog = "Voce causou " .. danoTotal .. " de dano!"
        atualizarTela(); os.sleep(0.8)
        turnoInimigo(); atualizarTela()
    end
end

-- =======================================================
-- 🖱️ LOOP PRINCIPAL DE EVENTOS
-- =======================================================
local function loopJogo()
    atualizarTela()
    while rodando do
        local ev, _, x, y = os.pullEvent("monitor_touch")
        local larg, _ = mon.getSize()
        
        if ESTADO == "MENU" then
            local temSave = fs.exists(ARQUIVO_SAVE)
            if temSave and y >= 7 and y <= 9 then
                carregarJogo(); gerarEncontro()
            elseif (not temSave and y >= 9 and y <= 11) or (temSave and y >= 11 and y <= 13) then
                resetarJogador(); gerarEncontro()
            end

        elseif ESTADO == "LOJA" then
            if y >= 7 and y <= 9 then
                if x >= 2 and x <= 28 and jogador.ouro >= 15 then
                    jogador.ouro = jogador.ouro - 15; jogador.pocoes = jogador.pocoes + 1
                    mensagemLoja = "Comprou 1 Pocao!"; tocar("entity.experience_orb.pickup", 1)
                elseif x >= 30 and jogador.ouro >= 30 then
                    jogador.ouro = jogador.ouro - 30; jogador.pocoesMax = jogador.pocoesMax + 1
                    mensagemLoja = "Comprou Super Pocao!"; tocar("entity.experience_orb.pickup", 1)
                end
            elseif y >= 11 and y <= 13 then
                if x >= 2 and x <= 28 and jogador.ouro >= 40 then
                    jogador.ouro = jogador.ouro - 40; jogador.danoExtra = jogador.danoExtra + 5
                    mensagemLoja = "Comprou Espada (+5 Dano)!"; tocar("item.armor.equip_iron", 1)
                elseif x >= 30 and jogador.ouro >= 40 then
                    jogador.ouro = jogador.ouro - 40; jogador.defesa = jogador.defesa + 2
                    mensagemLoja = "Comprou Escudo (+2 Def)!"; tocar("item.shield.equip", 1)
                end
            elseif y >= 15 and y <= 17 then
                if x >= 2 and x <= 28 and jogador.ouro >= 50 then
                    jogador.ouro = jogador.ouro - 50; jogador.maxHp = jogador.maxHp + 20; jogador.hp = jogador.hp + 20
                    mensagemLoja = "Comprou Armadura (+20 MaxHP)!"; tocar("item.armor.equip_diamond", 1)
                elseif x >= 30 and jogador.ouro >= 60 then
                    jogador.ouro = jogador.ouro - 60; jogador.xp = jogador.xp + 30
                    mensagemLoja = "Bebeu Elixir (+30 XP)!"; tocar("entity.generic.drink", 1)
                end
            elseif y >= 19 and y <= 21 then
                salvarJogo(); ESTADO = estadoAnterior
            end
            atualizarTela()

        elseif ESTADO == "BATALHA" then
            if y == 1 and x >= larg - 6 then
                salvarJogo(); ESTADO = "MENU"; atualizarTela() -- Usa o menu como Pause
            elseif y >= 14 and y <= 16 then
                if x >= 2 and x <= 12 then
                    processarCombate()
                elseif x >= 14 and x <= 26 then
                    if jogador.pocoes > 0 or jogador.pocoesMax > 0 then
                        local curouMax = false
                        if jogador.pocoesMax > 0 then
                            jogador.pocoesMax = jogador.pocoesMax - 1
                            jogador.hp = math.min(jogador.maxHp, jogador.hp + 50)
                            curouMax = true
                        else
                            jogador.pocoes = jogador.pocoes - 1
                            jogador.hp = math.min(jogador.maxHp, jogador.hp + 25)
                        end
                        mensagemLog = curouMax and "Usou Super Pocao!" or "Usou Pocao Normal!"
                        tocar("entity.generic.drink", 1); atualizarTela(); os.sleep(0.8)
                        turnoInimigo(); atualizarTela()
                    else
                        mensagemLog = "Voce nao tem pocoes!"; atualizarTela()
                    end
                elseif x >= 28 and x <= 38 then
                    estadoAnterior = "BATALHA"; mensagemLoja = ""; ESTADO = "LOJA"; atualizarTela()
                elseif x >= 40 and x <= 51 then
                    if math.random(1, 2) == 1 then
                        mensagemLog = "Fugiu com sucesso!"; tocar("entity.player.breath", 1)
                        atualizarTela(); os.sleep(1); gerarEncontro()
                    else
                        mensagemLog = "Falha ao fugir!"; tocar("entity.villager.no", 1)
                        atualizarTela(); os.sleep(0.8); turnoInimigo(); atualizarTela()
                    end
                end
            end
        end
    end
end

-- =======================================================
-- 🚀 EXECUÇÃO PARALELA (MÚSICA + JOGO)
-- =======================================================
print("🎮 Pilgramo rodando no monitor!")
print("Pressione 'Q' neste terminal para sair.")

local function escutarSaida()
    while rodando do
        local _, p1 = os.pullEvent("key")
        if p1 == keys.q then
            rodando = false
            mon.setBackgroundColor(colors.black); mon.clear()
            print("Jogo encerrado.")
        end
    end
end

parallel.waitForAny(escutarSaida, loopJogo, loopMusica)
