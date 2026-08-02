-- Abre a conexão de rede no modem que estiver conectado
peripheral.find("modem", rednet.open)
local speaker = peripheral.find("speaker")

if not speaker then
    print("Erro: Speaker nao encontrado neste computador!")
    return
end

print("Caixa de Som ligada! Aguardando o jogo iniciar...")

local tocando = false
local volume = 0.6

local function semitomParaPitch(semitom)
    return 2 ^ ((semitom - 12) / 12)
end

-- Melodia 8-Bit do Pilgramo
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

-- Fica escutando as ordens do Computador 1
local function escutarRede()
    while true do
        local id, mensagem = rednet.receive()
        if mensagem == "TOCA_MUSICA" then
            tocando = true
            print("Tocando musica!")
        elseif mensagem == "PARA_MUSICA" then
            tocando = false
            print("Musica pausada.")
        end
    end
end

-- Toca a música em loop se a ordem for 'tocando = true'
local function tocarLoop()
    local idx = 1
    while true do
        if tocando then
            local nota = melodia[idx]
            pcall(function() speaker.playSound("block.note_block.harp", volume, semitomParaPitch(nota[1])) end)
            idx = (idx % #melodia) + 1
            os.sleep(nota[2])
        else
            os.sleep(0.5) -- Pausa se o jogo pedir para parar
        end
    end
end

-- Roda os dois sistemas ao mesmo tempo
parallel.waitForAny(escutarRede, tocarLoop)
