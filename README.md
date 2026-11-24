# hub-base

Um menu, varios jogos. O hub detecta o jogo pelo `PlaceId` e carrega o modulo certo.

## Link

```
loadstring(game:HttpGet("https://cdn.jsdelivr.net/gh/whesleydev/hub-base@v1/base.lua"))()
```

## Como portar para outro jogo

Cada jogo e um modulo com tres funcoes. Nada mais.

```lua
Modules.meujogo = {
    name = "Meu Jogo",
    placeIds = {123456789},
    enemies = function()
        -- retorna {{model = Model, part = BasePart}, ...}
    end,
    targets = function()
        -- frutas, baus, drops
    end,
    playerLevel = function()
        return 1
    end,
}
```

O hub faz o resto: farm, kill aura, fast attack, hitbox, ESP (nome, vida,
distancia, tracer, caixa, esqueleto, chams), voo, teleporte, FPS e log.

## Modulos incluidos

| modulo | jogo |
|---|---|
| `bloxfruits` | Blox Fruits (3 places) |
| `generic` | qualquer jogo (varredura do workspace) |

## Abas

Farm, Movimento, ESP, Teleporte, FPS, Misc.

## Log

Painel na tela + copiar + link via paste.rs. Igual ao do Blox Fruits.
