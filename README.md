# 🎖️ History-I — Game Design Document (GDD)
**Versión:** 1.0 | **Motor:** Roblox Studio + Luau  
**Stack técnico:** Knit · ProfileService · Trove · Signal · Janitor  
**Metodología:** Arquitectura MVC + Servicios desacoplados (patrón AAA Roblox)

---

# Estado actual del proyecto

Actualizado: 2026-05-18

Este bloque resume el estado real del codigo actual. El resto del README sigue funcionando como GDD/base de diseno, pero algunas rutas antiguas del documento no coinciden todavia con la estructura actual `Match/...`.

## Ultimos cambios conectados

- Sistema de seleccion de Nexo agregado en servidor con `NexoService`.
- `NexoService` descubre instancias tageadas con `CollectionService` usando tags que contengan `Nexo`.
- Cada Nexo detectado se asocia al hexagono debajo y bloquea el socket `Center` con `BuildService:BlockHexCenter`, evitando construir encima.
- Fase `NexoSelection` agregada a `MatchStates`, `PlayerStates` y `RuntimeTypes`.
- `GameService` ahora puede iniciar y cerrar la seleccion de Nexo con `BeginNexoSelection` y `FinishNexoSelection`.
- Jugadores que entran durante `NexoSelection` o `Playing` son sincronizados al estado correcto.
- Cliente de seleccion de Nexo agregado con `NexoSelectionController`, menu de confirmacion, timer, highlight local y feedback de Nexo seleccionado por otro jugador.
- Corregido el bloqueo de clicks por overlays transparentes de UI: la seleccion de Nexo, construccion e interaccion de edificios ya ignoran frames transparentes no interactivos.
- UI de construccion movida a `Match/client/UIs/BuildControls/index.luau`.
- Menu de edificio movido a `Match/client/Menus/BuildingMenu/index.luau`.
- `BuildService` expone snapshots de sockets con `BlockedReason` para diferenciar ocupacion normal de bloqueo por Nexo.

## Flujo actual esperado

1. El servidor inicia en `WaitingForPlayers`.
2. `NexoService` espera un momento, descubre Nexos tageados y llama `GameService:BeginNexoSelection`.
3. Los jugadores pasan a `NexoSelection`.
4. El cliente muestra timer y permite hacer click sobre un Nexo disponible.
5. Click sobre Nexo abre menu; confirmar llama `ClaimNexo`.
6. Si todos reclaman o se acaba el timer, `NexoService` asigna faltantes automaticamente.
7. `GameService:FinishNexoSelection` mueve la partida a `Playing`.
8. Desde `Playing`, el jugador puede entrar a modo construccion y `BuildService` valida colocaciones.

## Requisitos de setup en Studio

- Cada hexagono del tablero debe tener tag `BuildableHex`.
- Cada Nexo debe tener un tag que contenga `Nexo`, por ejemplo `Nexo` o `NexoNorte`.
- El Nexo debe estar como `Model` o `BasePart` encima de un hexagono buildable.
- Opcional en cada Nexo:
  - Attribute `NexoId`: id estable para snapshots/UI.
  - Attribute `DisplayName`: nombre visible.
  - Attribute `Lore`: descripcion mostrada en el menu.
- Las partes visibles del Nexo deben tener `CanQuery = true` para que el raycast del cliente pueda seleccionarlas.

## TODO prioritario

- [ ] Validar en Roblox Studio con 1 jugador: se detectan Nexos, aparece timer, click abre menu, confirmar asigna y pasa a `Playing`.
- [ ] Validar en Roblox Studio con 2+ jugadores: dos jugadores no pueden confirmar el mismo Nexo al mismo tiempo; el segundo ve estado `selected` o `taken`.
- [ ] Conectar la asignacion de Nexo con spawn/base inicial del jugador. Ahora se asigna el Nexo, pero no crea base ni posicion inicial de ejercito.
- [ ] Definir que ocurre despues de `Playing`: condiciones de victoria/derrota, captura/destruccion del Nexo y fin de partida.
- [ ] Conectar economia real por Nexo/base. `BuildService` maneja recursos locales de partida, pero no hay produccion por territorio todavia.
- [ ] Conectar ownership visual y logico del Nexo en el mapa para que otros sistemas puedan consultar `OwnerUserId`.
- [ ] Agregar acciones reales al menu de edificio. Hoy muestra tipo y HP, pero no tiene reparar, vender, producir unidades ni upgrades.
- [ ] Agregar dano/combate contra edificios y Nexos. Hay HP en edificios, pero no hay `CombatService` conectado al sistema.
- [ ] Revisar si `NexoService` debe reiniciar correctamente cuando empieza otra partida en el mismo servidor.
- [ ] Agregar tests o checklist manual corto para `NexoService`, `BuildService:BlockHexCenter` y transiciones de `GameService`.

## Pendiente tecnico / riesgos

- `README.md` debe mantenerse en UTF-8; si PowerShell muestra caracteres raros, revisar la codificacion de la consola antes de editar.
- Hay archivos nuevos no trackeados del sistema de Nexo (`NexoService`, `NexoSelectionController`, menus y UIs). Antes de cerrar esta feature, revisar `git status` y confirmar que todos entren al commit.
- Tooling local integrado con Rokit: `stylua` y `selene` quedan fijados en `rokit.toml`. En una maquina nueva, ejecutar `rokit install`. Validacion recomendada: `stylua --check Match`, `selene Match` y `rojo sourcemap default.project.json --output NUL`.
- La seleccion depende de raycast contra las instancias de Nexo; si un modelo visual tiene partes `CanQuery = false`, el click no lo detectara.
- La asignacion automatica al terminar el timer puede reutilizar un Nexo ya tomado si hay mas jugadores que Nexos. Definir si eso es valido para el diseno.

---

## 📋 ÍNDICE
1. [Visión General](#visión-general)
2. [Stack Técnico y Estructura de Proyecto](#stack-técnico)
3. [Fase 0 — Pre-Producción](#fase-0)
4. [Fase 1 — El Esqueleto del Comandante](#fase-1)
5. [Fase 2 — El Cerebro del Tablero](#fase-2)
6. [Fase 3 — Sistema de Construcción AAA](#fase-3)
7. [Fase 4 — Economía, Ejército y el Nexo](#fase-4)
8. [Fase 5 — Mutadores Históricos (Live Events)](#fase-5)
9. [Fase 6 — Pulido, Audio y VFX](#fase-6)
10. [Fase 7 — Monetización y Retención](#fase-7)
11. [Convenciones de Código](#convenciones)
12. [Checklist de QA por Fase](#checklist-qa)

---

## 1. Visión General <a name="visión-general"></a>

**Género:** RTS (Real-Time Strategy) de tablero hexagonal multijugador  
**Tema:** Primera y Segunda Guerra Mundial — conflictos históricos con mutadores  
**Cámara:** Vista cenital flotante (sin personaje físico)  
**Jugadores por servidor:** 2–6 jugadores  
**Duración de partida objetivo:** 15–25 minutos  

**Pilares de diseño (los 3 principios que guían cada decisión):**
1. **Legibilidad** — Cualquier acción en el tablero debe entenderse de un vistazo.
2. **Imprevisibilidad controlada** — Los mutadores históricos añaden caos sin romper el balance.
3. **Escalabilidad** — El código debe poder añadir nuevas unidades/edificios sin refactorizar el núcleo.

## 2. Stack Técnico y Estructura de Proyecto <a name="stack-técnico"></a>

### 2.1 Librerías requeridas (instalar antes de escribir UNA SOLA línea)

| Librería | Propósito | Ubicación en Studio |
|---|---|---|
| **Knit** | Framework cliente/servidor, servicios y controladores | `ReplicatedStorage/Packages` |
| **ProfileService** | DataStore seguro con session-locking (previene duplicación) | `ServerScriptService/Packages` |
| **Trove** | Gestor de limpieza de conexiones (previene memory leaks) | `ReplicatedStorage/Packages` |
| **Signal** | Eventos tipados y desacoplados | `ReplicatedStorage/Packages` |

> ⚠️ **REGLA DE ORO:** Nunca uses `game:GetService("DataStoreService")` directamente. Todo pasa por ProfileService. Nunca conectes un `.Changed` sin guardarlo en un Trove/Janitor.

### 2.2 Estructura de carpetas del proyecto

ServerScriptService/
Services/               ← Knit Services (solo corren en servidor)
GameService.lua       ← Orquesta el ciclo de vida de la partida
BuildService.lua      ← Valida y ejecuta construcciones
EconomyService.lua    ← Tick económico y recursos
CombatService.lua     ← Resolución de combate
EventService.lua      ← Mutadores históricos
DataService.lua       ← Wrapper de ProfileService

Shared/
Constants.lua         ← Todas las constantes del juego (costos, HP, tiempos)
HexUtils.lua          ← Funciones matemáticas de cuadrícula hexagonal
Types.lua             ← Definiciones de tipos (TypeScript-style comments)
Assets/
Buildings/            ← Modelos de edificios (prefabs)
Units/                ← Modelos de tropas
VFX/                  ← Efectos de partícula

StarterPlayerScripts/
Controllers/            ← Knit Controllers (solo corren en cliente)
CameraController.lua  ← Cámara cenital y movimiento WASD
BuildController.lua   ← Preview, rotación y colocación de edificios
UIController.lua      ← Maneja toda la UI del jugador
InputController.lua   ← Centraliza todo UserInputService
StarterGui/
HUD/                    ← ScreenGui principal (recursos, botones de acción)
BuildMenu/              ← Panel de construcción
EventBanner/            ← UI de mutadores históricos


---

## 3. Fase 0 — Pre-Producción (Día 0, OBLIGATORIA) <a name="fase-0"></a>

> Los estudios AAA no escriben código hasta que el mapa de sistemas está claro. Tú tampoco.

### 3.1 Definir la tabla Constants.lua ANTES de codificar
Crea `ReplicatedStorage/Shared/Constants.lua` con **todos** los valores numéricos del juego:

```lua
-- Constants.lua
return {
  -- Economía
  GOLD_TICK_INTERVAL = 5,           -- segundos entre cada tick de oro
  BASE_GOLD_PER_TICK = 10,
  SAWMILL_GOLD_BONUS = 5,

  -- Edificios: costo y HP
  BUILDINGS = {
    Nexus      = { Gold = 0,   Population = 0,  HP = 500, BuildTime = 0   },
    House      = { Gold = 50,  Population = 0,  HP = 150, BuildTime = 8   },
    Sawmill    = { Gold = 75,  Population = 2,  HP = 100, BuildTime = 10  },
    Barracks   = { Gold = 120, Population = 3,  HP = 200, BuildTime = 15  },
    Artillery  = { Gold = 200, Population = 5,  HP = 80,  BuildTime = 20  },
  },

  -- Unidades
  UNITS = {
    Infantry  = { Gold = 30, Food = 1, HP = 100, Damage = 20, Speed = 16 },
    LightTank = { Gold = 80, Food = 2, HP = 250, Damage = 50, Speed = 10 },
    Mortar    = { Gold = 60, Food = 2, HP = 70,  Damage = 90, Speed = 6  },
  },

  -- Eventos históricos
  EVENT_INTERVAL_MIN = 180,   -- 3 minutos
  EVENT_INTERVAL_MAX = 300,   -- 5 minutos
  EVENT_DURATION = 60,        -- duración en segundos

 --------------------------------------------------------------------------------
-- GEOMETRÍA HEXAGONAL
--------------------------------------------------------------------------------

--- Ancho total del hexágono en el eje X (en studs).
--- Para tus piezas personalizadas, esto es 9
GridConfig.HexWidth = 9

--- Altura total del hexágono en el eje Z (profundidad, punta a punta).
--- Para tus piezas personalizadas, esto es 10
GridConfig.HexHeight = 10     

--- Origen lógico de la grilla. El hexágono en X/Z = 0,0 calcula Q/R = 0,0.
--- No se asignan atributos Q/R manuales; servidor y cliente calculan coordenadas
--- desde la posición mundial del MeshPart.
GridConfig.GridOrigin = Vector3.zero

--- Tolerancia máxima entre la posición real del MeshPart y el centro matemático
--- de la celda axial calculada. Si se supera, el scanner advierte e ignora el hex.
GridConfig.HexSnapTolerance = 1.25

GridConfig.TerrainTypes = {
	Plain = "Plain", -- Llanura — se puede construir todo
	Water = "Water", -- Agua    — no se puede construir nada
	Forest = "Forest", -- Bosque  — no se puede construir nada
}

--- Terreno por defecto (si la pieza no tiene el Attribute "TerrainType").
GridConfig.DefaultTerrainType = "Plain"

GridConfig.BuildableTerrains = {
	["Plain"] = true,
	["Water"] = false,
	["Forest"] = false,
}

--------------------------------------------------------------------------------
-- ETIQUETAS (CollectionService Tags)
--------------------------------------------------------------------------------

--- Tag que deben tener los MeshPart del mapa en Roblox Studio.
--- Todas las piezas hexagonales del tablero usan este tag, sin importar su terreno.
--- No uses Model, PrimaryPart, Attachments ni atributos Q/R para el tablero base.
GridConfig.BuildableHexTag = "BuildableHex"

--------------------------------------------------------------------------------
-- OPTIMIZACIÓN DEL TERRENO — Propiedades para hexágonos base
--------------------------------------------------------------------------------

--- Si true, el scanner aplicará automáticamente las optimizaciones de rendimiento
--- a cada hexágono escaneado (Anchored, CastShadow, etc.).
GridConfig.AutoOptimizeHexParts = true

GridConfig.HexPartDefaults = {
	--- Las piezas del tablero DEBEN estar ancladas.
	Anchored = true,

	--- Desactivar sombras en los hexágonos base; las sombras superpuestas de
	--- cientos de piezas planas destruyen los FPS en dispositivos móviles.
	CastShadow = false,

	--- Los hexágonos base NO deben tener colisión individual.
	--- Un bloque invisible grande y plano actúa como suelo de colisión en su lugar,
	--- evitando que Roblox calcule colisiones para cada pieza por separado.
	CanCollide = true,

	--- Desactivar queries de toque y raycast en las piezas del suelo
	--- (el sistema de construcción usará coordenadas axiales, no raycasts).
	CanTouch = false,
	CanQuery = true,
}

--------------------------------------------------------------------------------
-- SLOTS DE CONSTRUCCIÓN POR HEXÁGONO
--------------------------------------------------------------------------------

--- Cantidad máxima de muros (paredes) que se pueden colocar por hexágono.
--- Corresponde a los 6 lados del hexágono; cada muro ocupa un borde.
GridConfig.MaxWallsPerHex = 6
GridConfig.MaxBuildingsPerHex = 1  -- Solo un edificio por hexágono, sin contar muros
```

> **¿Por qué?** Si cambias el costo de un edificio desde Constants.lua, se actualiza en servidor, cliente y UI automáticamente. Nunca más busques números "mágicos" enterrados en scripts.

### 3.2 Definir el schema de datos de ProfileService

```lua
-- DataService.lua — Schema template (lo que se guarda por jugador)
local ProfileTemplate = {
  Stats = {
    TotalWins  = 0,
    GamesPlayed = 0,
  },
  Cosmetics = {
    SelectedFlag = "Default",
  },
  -- Los recursos de partida NO se guardan aquí (son efímeros)
}
```

---

## 4. Fase 1 — El Esqueleto del Comandante (Días 1–2) <a name="fase-1"></a>

### 4.1 Limpieza de CoreGui

**Archivo:** `StarterPlayerScripts/Controllers/UIController.lua`

**Instrucción precisa:**
1. Dentro del método `KnitInit` del controlador, usa `SetCoreGuiEnabled` para deshabilitar: `Enum.CoreGuiType.Backpack`, `Enum.CoreGuiType.PlayerList`, `Enum.CoreGuiType.EmotesMenu`, `Enum.CoreGuiType.Health`.
2. **NO** deshabilites `Enum.CoreGuiType.Chat` — mantenlo activo para comunicación entre jugadores.
3. Valida que funcione probando con `/` en el juego: el chat debe aparecer, el inventario NO.

### 4.2 El "No-Personaje" (servidor)

**Archivo:** `ServerScriptService/Services/GameService.lua`

**Instrucción precisa:**
1. En `ServerScriptService`, crea un `Script` que en `game.Players.PlayerAdded` establezca `Players.CharacterAutoLoads = false` **antes** de que cualquier jugador entre.
2. Cuando el servidor decida que la partida comenzó (`GameService:StartMatch()`), llama a `player:LoadCharacter()` SOLO si necesitas un modelo de referencia. En este juego no lo necesitas — omítelo.
3. **Test de validación:** Al entrar al juego, el jugador NO debe ver un personaje spawneando. La pantalla debe verse en negro hasta que la cámara se posicione.

### 4.3 La Cámara Cenital Flotante

**Archivo:** `StarterPlayerScripts/Controllers/CameraController.lua`

**Instrucción precisa (paso a paso):**

1. **Crea el "dron" (servidor → cliente):** En `GameService`, cuando un jugador entra a la partida, crea una `BasePart` invisible (`Transparency = 1, CanCollide = false, Anchored = false`) en el mapa. Nómbrala `Drone_{UserId}` y ponla en `Workspace`. Asígnala al jugador vía un atributo o RemoteEvent.

2. **Movimiento sin gravedad:** Aplica `LinearVelocity` (Attachment0 en el Drone, RelativeTo = World) al Drone. **No uses BodyPosition** — está deprecado. Configura `MaxForce = Vector3.new(1e5, 1e5, 1e5)`.

3. **Input WASD en el cliente:** En `CameraController`, escucha `UserInputService.InputChanged` y `RunService.Heartbeat`. En cada Heartbeat, calcula el vector de dirección deseado:
   - W/S → eje Z del mundo
   - A/D → eje X del mundo
   - Normaliza el vector y multiplícalo por `CAMERA_SPEED` (definido en Constants.lua, valor inicial sugerido: `40`).
   - Envía la velocidad deseada al servidor via RemoteEvent `SetDroneVelocity` cada Heartbeat.
   - Al soltar las teclas, envía `Vector3.zero` — el `LinearVelocity` frenará suavemente por inercia.

4. **Ancla la cámara:** En el cliente, en cada `Heartbeat`:
```lua
   camera.CFrame = CFrame.new(
     drone.Position + Vector3.new(0, CAMERA_HEIGHT, 0),
     drone.Position  -- mira hacia abajo al punto del dron
   )
   camera.CameraType = Enum.CameraType.Scriptable
```
   `CAMERA_HEIGHT` inicial: `60` studs. Este valor cambia durante el evento "Niebla de Guerra".

5. **Límites del mapa:** En el servidor, valida que la posición del Drone no salga del bounding box del mapa. Si sale, clampea la posición.

### 4.4 Máquina de Estados (FSM)

**Archivo:** `ServerScriptService/Services/GameService.lua`

**Estados del jugador:**
[Connecting] → [Lobby] → [LoadingMatch] → [Playing] → [Defeated] → [Spectating]
↑                                          |
└──────────────── [MatchEnd] ─────────────┘

**Instrucción precisa:**
1. Crea un módulo `StateMachine.lua` en `ReplicatedStorage/Shared/` con métodos: `new(initialState)`, `:TransitionTo(newState)`, `:GetState()`, `:OnTransition(callback)`.
2. En `GameService`, cada jugador tiene su propia instancia de `StateMachine`.
3. Cada transición dispara un `Signal` que otros servicios pueden escuchar. Ejemplo: cuando un jugador pasa a `Defeated`, `CombatService` escucha ese Signal y desactiva sus unidades; `UIController` (cliente) recibe un RemoteEvent y muestra la pantalla de derrota.
4. **Test de validación:** Imprime en el Output cada transición de estado con `[FSM] PlayerName: OldState → NewState`. Verifica el flujo completo una vez antes de continuar.

