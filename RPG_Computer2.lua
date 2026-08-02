local speaker = peripheral.find("speaker")

if not speaker then
    print("ERRO: Coloque um bloco 'Speaker' encostado neste computador!")
    return
end

print("=============================")
print(" 📻 RÁDIO PILGRAMO LIGADA!   ")
print("=============================")
print("Tocando a trilha sonora 8-Bit infinita...")
print("Pressione CTRL+T segurado para desligar.")

local volume = 1.0

-- Fórmula para afinar o som do Minecraft perfeitamente
local function semitomParaPitch(semitom)
    return 2 ^ ((semitom - 12) / 12)
end

-- A melodia heroica do jogo
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

-- Loop infinito de música
while true do
    for i = 1, #melodia do
        local nota = melodia[i]
        
        -- O pcall garante que se o som falhar 1 vez, o rádio não desliga
        pcall(function() 
            speaker.playSound("block.note_block.harp", volume, semitomParaPitch(nota[1])) 
        end)
        
        os.sleep(nota[2])
    end
    os.sleep(0.5) -- Pausa rápida antes de repetir a música
end
